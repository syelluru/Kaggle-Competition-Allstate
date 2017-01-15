# Score = 1118.19305

library(data.table)
library(Matrix)
library(xgboost)
library(Metrics)
library(Boruta)

## Set the variables

ID = 'id'
TARGET = 'loss'
SEED = 0
SHIFT = 200

## Load the files and Data

train = fread("train.csv", showProgress = TRUE)
test = fread("test.csv", showProgress = TRUE)

## Normalization using Log

y_train = log(train[,TARGET, with = FALSE] + SHIFT)[[TARGET]]

train[, c(ID, TARGET) := NULL]
test[, c(ID) := NULL]

ntrain = nrow(train)
train_test = rbind(train, test)

features = names(train)

## Function to sort the names of the features and factor according to levels uniformly
for (f in features) {
  if (class(train_test[[f]])=="character") {
    #cat("VARIABLE : ",f,"\n")
    levels <- sort(unique(train_test[[f]]))
    train_test[[f]] <- as.integer(factor(train_test[[f]], levels=levels))
  }
}

## Use feature selection and drop the features.
## Resultant feature set to be dropped

boruta.train <- Boruta(loss~.-id, data = traindata, doTrace = 2)
print(boruta.train)

# features_to_drop can be taken from boruta.train

features_to_drop <- c("cat67","cat21","cat60","cat65", "cat32", "cat30",
                      "cat24", "cat74", "cat85", "cat17", "cat14", "cat18",
                      "cat59", "cat22", "cat63", "cat56", "cat58", "cat55",
                      "cat33", "cat34", "cat46", "cat47", "cat48", "cat68",
                      "cat35", "cat20", "cat69", "cat70", "cat15", "cat62")

x_train = train_test[1:ntrain,-features_to_drop, with = FALSE]
x_test = train_test[(ntrain+1):nrow(train_test),-features_to_drop, with = FALSE]

## Applying the XGBoost algorithm

dtrain = xgb.DMatrix(as.matrix(x_train), label=y_train)
dtest = xgb.DMatrix(as.matrix(x_test))

xgb_params = list(
  seed = 0,
  colsample_bytree = 0.5,
  subsample = 0.8,
  eta = 0.05, 
  objective = 'reg:linear',
  max_depth = 12,
  alpha = 1,
  gamma = 2,
  min_child_weight = 1,
  base_score = 7.76
)


xg_eval_mae <- function (yhat, dtrain) {
  y = getinfo(dtrain, "label")
  err= mae(exp(y),exp(yhat) )
  return (list(metric = "error", value = err))
}

res = xgb.cv(xgb_params,
             dtrain,
             nrounds=750,
             nfold=4,
             early_stopping_rounds=15,
             print_every_n = 10,
             verbose= 1,
             feval=xg_eval_mae,
             maximize=FALSE)

best_nrounds = res$best_iteration
cv_mean = res$evaluation_log$test_error_mean[best_nrounds]
cv_std = res$evaluation_log$test_error_std[best_nrounds]
cat(paste0('CV-Mean: ',cv_mean,' ', cv_std))


# established best _nrounds with eta=0.05 
best_nrounds = 545 

gbdt = xgb.train(xgb_params, dtrain, nrounds=as.integer(best_nrounds/0.8))


## Prediction and making a submission

submission = fread("sample_submission.csv", colClasses = c("integer", "numeric"))
submission$loss = exp(predict(gbdt,dtest)) - SHIFT
write.csv(submission,'submissionFile.csv',row.names = FALSE)