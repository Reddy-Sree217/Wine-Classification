function [trainedClassifier, validationAccuracy] = trainClassifier(trainingData)
    % [trainedClassifier, validationAccuracy] = trainClassifier(trainingData)
    % Returns a trained classifier and its accuracy. This code recreates the
    % classification model trained in Classification Learner app. Use the
    % generated code to automate training the same model with new data, or to
    % learn how to programmatically train models.
    %
    %  Input:
    %      trainingData: A matrix with the same number of columns and data type
    %       as the matrix imported into the app.
    %
    %  Output:
    %      trainedClassifier: A struct containing the trained classifier. The
    %       struct contains various fields with information about the trained
    %       classifier.
    %
    %      trainedClassifier.predictFcn: A function to make predictions on new
    %       data.
    %
    %      validationAccuracy: A double containing the accuracy as a
    %       percentage. In the app, the Models pane displays this overall
    %       accuracy score for each model.
    %
    % Use the code to train the model with new data. To retrain your
    % classifier, call the function from the command line with your original
    % data or new data as the input argument trainingData.
    %
    % For example, to retrain a classifier trained with the original data set
    % T, enter:
    %   [trainedClassifier, validationAccuracy] = trainClassifier(T)
    %
    % To make predictions with the returned 'trainedClassifier' on new data T2,
    % use
    %   yfit = trainedClassifier.predictFcn(T2)
    %
    % T2 must be a matrix containing only the predictor columns used for
    % training. For details, enter:
    %   trainedClassifier.HowToPredict

    % Auto-generated by MATLAB on 10-Dec-2021 23:38:57


    % Extract predictors and response
    % This code processes the data into the right shape for training the
    % model.
    % Convert input to table
    inputTable = array2table(trainingData, 'VariableNames', {'column_1', 'column_2', 'column_3', 'column_4', 'column_5', 'column_6', 'column_7', 'column_8', 'column_9', 'column_10', 'column_11', 'column_12'});

    predictorNames = {'column_1', 'column_2', 'column_3', 'column_4', 'column_5', 'column_6', 'column_7', 'column_8', 'column_9', 'column_10', 'column_11'};
    predictors = inputTable(:, predictorNames);
    response = inputTable.column_12;
    isCategoricalPredictor = [false, false, false, false, false, false, false, false, false, false, false];

    % Apply a PCA to the predictor matrix.
    % Run PCA on numeric predictors only. Categorical predictors are passed through PCA untouched.
    isCategoricalPredictorBeforePCA = isCategoricalPredictor;
    numericPredictors = predictors(:, ~isCategoricalPredictor);
    numericPredictors = table2array(varfun(@double, numericPredictors));
    % 'inf' values have to be treated as missing data for PCA.
    numericPredictors(isinf(numericPredictors)) = NaN;
    [pcaCoefficients, pcaScores, ~, ~, explained, pcaCenters] = pca(...
        numericPredictors);
    % Keep enough components to explain the desired amount of variance.
    explainedVarianceToKeepAsFraction = 95/100;
    numComponentsToKeep = find(cumsum(explained)/sum(explained) >= explainedVarianceToKeepAsFraction, 1);
    pcaCoefficients = pcaCoefficients(:,1:numComponentsToKeep);
    predictors = [array2table(pcaScores(:,1:numComponentsToKeep)), predictors(:, isCategoricalPredictor)];
    isCategoricalPredictor = [false(1,numComponentsToKeep), true(1,sum(isCategoricalPredictor))];

    % Train a classifier
    % This code specifies all the classifier options and trains the classifier.
    % For logistic regression, the response values must be converted to zeros
    % and ones because the responses are assumed to follow a binomial
    % distribution.
    % 1 or true = 'successful' class
    % 0 or false = 'failure' class
    % NaN - missing response.
    successClass = double(1);
    failureClass = double(0);
    % Compute the majority response class. If there is a NaN-prediction from
    % fitglm, convert NaN to this majority class label.
    numSuccess = sum(response == successClass);
    numFailure = sum(response == failureClass);
    if numSuccess > numFailure
        missingClass = successClass;
    else
        missingClass = failureClass;
    end
    successFailureAndMissingClasses = [successClass; failureClass; missingClass];
    isMissing = isnan(response);
    zeroOneResponse = double(ismember(response, successClass));
    zeroOneResponse(isMissing) = NaN;
    % Prepare input arguments to fitglm.
    concatenatedPredictorsAndResponse = [predictors, table(zeroOneResponse)];
    % Train using fitglm.
    GeneralizedLinearModel = fitglm(...
        concatenatedPredictorsAndResponse, ...
        'Distribution', 'binomial', ...
        'link', 'logit');

    % Convert predicted probabilities to predicted class labels and scores.
    convertSuccessProbsToPredictions = @(p) successFailureAndMissingClasses( ~isnan(p).*( (p<0.5) + 1 ) + isnan(p)*3 );
    returnMultipleValuesFcn = @(varargin) varargin{1:max(1,nargout)};
    scoresFcn = @(p) [1-p, p];
    predictionsAndScoresFcn = @(p) returnMultipleValuesFcn( convertSuccessProbsToPredictions(p), scoresFcn(p) );

    % Create the result struct with predict function
    predictorExtractionFcn = @(x) array2table(x, 'VariableNames', predictorNames);
    pcaTransformationFcn = @(x) [ array2table((table2array(varfun(@double, x(:, ~isCategoricalPredictorBeforePCA))) - pcaCenters) * pcaCoefficients), x(:,isCategoricalPredictorBeforePCA) ];
    logisticRegressionPredictFcn = @(x) predictionsAndScoresFcn( predict(GeneralizedLinearModel, x) );
    trainedClassifier.predictFcn = @(x) logisticRegressionPredictFcn(pcaTransformationFcn(predictorExtractionFcn(x)));

    % Add additional fields to the result struct
    trainedClassifier.PCACenters = pcaCenters;
    trainedClassifier.PCACoefficients = pcaCoefficients;
    trainedClassifier.GeneralizedLinearModel = GeneralizedLinearModel;
    trainedClassifier.SuccessClass = successClass;
    trainedClassifier.FailureClass = failureClass;
    trainedClassifier.MissingClass = missingClass;
    trainedClassifier.ClassNames = {successClass; failureClass};
    trainedClassifier.About = 'This struct is a trained model exported from Classification Learner R2021b.';
    trainedClassifier.HowToPredict = sprintf('To make predictions on a new predictor column matrix, X, use: \n  yfit = c.predictFcn(X) \nreplacing ''c'' with the name of the variable that is this struct, e.g. ''trainedModel''. \n \nX must contain exactly 11 columns because this model was trained using 11 predictors. \nX must contain only predictor columns in exactly the same order and format as your training \ndata. Do not include the response column or any columns you did not import into the app. \n \nFor more information, see <a href="matlab:helpview(fullfile(docroot, ''stats'', ''stats.map''), ''appclassification_exportmodeltoworkspace'')">How to predict using an exported model</a>.');

    % Extract predictors and response
    % This code processes the data into the right shape for training the
    % model.
    % Convert input to table
    inputTable = array2table(trainingData, 'VariableNames', {'column_1', 'column_2', 'column_3', 'column_4', 'column_5', 'column_6', 'column_7', 'column_8', 'column_9', 'column_10', 'column_11', 'column_12'});

    predictorNames = {'column_1', 'column_2', 'column_3', 'column_4', 'column_5', 'column_6', 'column_7', 'column_8', 'column_9', 'column_10', 'column_11'};
    predictors = inputTable(:, predictorNames);
    response = inputTable.column_12;
    isCategoricalPredictor = [false, false, false, false, false, false, false, false, false, false, false];

    % Perform cross-validation
    KFolds = 10;
    cvp = cvpartition(response, 'KFold', KFolds);
    % Initialize the predictions to the proper sizes
    validationPredictions = response;
    numObservations = size(predictors, 1);
    numClasses = 2;
    validationScores = NaN(numObservations, numClasses);
    for fold = 1:KFolds
        trainingPredictors = predictors(cvp.training(fold), :);
        trainingResponse = response(cvp.training(fold), :);
        foldIsCategoricalPredictor = isCategoricalPredictor;

        % Apply a PCA to the predictor matrix.
        % Run PCA on numeric predictors only. Categorical predictors are passed through PCA untouched.
        isCategoricalPredictorBeforePCA = foldIsCategoricalPredictor;
        numericPredictors = trainingPredictors(:, ~foldIsCategoricalPredictor);
        numericPredictors = table2array(varfun(@double, numericPredictors));
        % 'inf' values have to be treated as missing data for PCA.
        numericPredictors(isinf(numericPredictors)) = NaN;
        [pcaCoefficients, pcaScores, ~, ~, explained, pcaCenters] = pca(...
            numericPredictors);
        % Keep enough components to explain the desired amount of variance.
        explainedVarianceToKeepAsFraction = 95/100;
        numComponentsToKeep = find(cumsum(explained)/sum(explained) >= explainedVarianceToKeepAsFraction, 1);
        pcaCoefficients = pcaCoefficients(:,1:numComponentsToKeep);
        trainingPredictors = [array2table(pcaScores(:,1:numComponentsToKeep)), trainingPredictors(:, foldIsCategoricalPredictor)];
        foldIsCategoricalPredictor = [false(1,numComponentsToKeep), true(1,sum(foldIsCategoricalPredictor))];

        % Train a classifier
        % This code specifies all the classifier options and trains the classifier.
        % For logistic regression, the response values must be converted to zeros
        % and ones because the responses are assumed to follow a binomial
        % distribution.
        % 1 or true = 'successful' class
        % 0 or false = 'failure' class
        % NaN - missing response.
        successClass = double(1);
        failureClass = double(0);
        % Compute the majority response class. If there is a NaN-prediction from
        % fitglm, convert NaN to this majority class label.
        numSuccess = sum(trainingResponse == successClass);
        numFailure = sum(trainingResponse == failureClass);
        if numSuccess > numFailure
            missingClass = successClass;
        else
            missingClass = failureClass;
        end
        successFailureAndMissingClasses = [successClass; failureClass; missingClass];
        isMissing = isnan(trainingResponse);
        zeroOneResponse = double(ismember(trainingResponse, successClass));
        zeroOneResponse(isMissing) = NaN;
        % Prepare input arguments to fitglm.
        concatenatedPredictorsAndResponse = [trainingPredictors, table(zeroOneResponse)];
        % Train using fitglm.
        GeneralizedLinearModel = fitglm(...
            concatenatedPredictorsAndResponse, ...
            'Distribution', 'binomial', ...
            'link', 'logit');

        % Convert predicted probabilities to predicted class labels and scores.
        convertSuccessProbsToPredictions = @(p) successFailureAndMissingClasses( ~isnan(p).*( (p<0.5) + 1 ) + isnan(p)*3 );
        returnMultipleValuesFcn = @(varargin) varargin{1:max(1,nargout)};
        scoresFcn = @(p) [1-p, p];
        predictionsAndScoresFcn = @(p) returnMultipleValuesFcn( convertSuccessProbsToPredictions(p), scoresFcn(p) );

        % Create the result struct with predict function
        pcaTransformationFcn = @(x) [ array2table((table2array(varfun(@double, x(:, ~isCategoricalPredictorBeforePCA))) - pcaCenters) * pcaCoefficients), x(:,isCategoricalPredictorBeforePCA) ];
        logisticRegressionPredictFcn = @(x) predictionsAndScoresFcn( predict(GeneralizedLinearModel, x) );
        validationPredictFcn = @(x) logisticRegressionPredictFcn(pcaTransformationFcn(x));

        % Add additional fields to the result struct

        % Compute validation predictions
        validationPredictors = predictors(cvp.test(fold), :);
        [foldPredictions, foldScores] = validationPredictFcn(validationPredictors);

        % Store predictions in the original order
        validationPredictions(cvp.test(fold), :) = foldPredictions;
        validationScores(cvp.test(fold), :) = foldScores;
    end

    % Compute validation accuracy
    correctPredictions = (validationPredictions == response);
    isMissing = isnan(response);
    correctPredictions = correctPredictions(~isMissing);
    validationAccuracy = sum(correctPredictions)/length(correctPredictions);
