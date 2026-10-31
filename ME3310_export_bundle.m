function outputs = ME3310_export_bundle(modelPath,modelBundle,R,trials,axTop,axBottom)
% ME3310_EXPORT_BUNDLE  Reproducible evidence archive for Weeks 11 and 12.
% Writes a human-readable *_metadata.txt alongside a frozen ML model (.mat),
% trial-level measurements (.csv), predictions (.csv), figures, and copies
% of actual source MAT recordings. Classifier parameters and split identities
% are recorded; no invented or augmented measurements are exported.
%
% INPUTS are the actual GUI state. Use ME3310_IMU_Analyzer to call it.
% This function does not train or modify a classifier.

if isempty(R) || isempty(modelBundle)
    error('ME3310:Export','Fit or load/evaluate a model before exporting.');
end
[folder,stem,ext] = fileparts(char(modelPath));
if isempty(ext),ext='.mat';end
if ~exist(folder,'dir'),mkdir(folder);end
base=fullfile(folder,stem);
mode='Week 11 preliminary held-out';
if ~any(R.train)
    mode='Week 12 independent validation with frozen Week 11 classifier';
end
createdAt=datestr(now,'yyyy-mm-dd HH:MM:SS');

% Distinct MAT files: machine-readable ML plus this evaluation's numerical
% evidence. The immutable training model lives in modelBundle.
analysis=R; %#ok<NASGU>
matFile=[base ext];
save(matFile,'modelBundle','analysis','-v7');

% Every original recording is one observational unit; windows are not new
% independent observations. Export trials + all 16 computed features.
n=numel(trials);
paths=cell(n,1);roles=cell(n,1);labels=zeros(n,1);
for k=1:n
    paths{k}=trials(k).path;
    if R.train(k),roles{k}='DevelopmentTrain';
    else
        if any(R.train),roles{k}='Week11PreliminaryHoldout';
        else,roles{k}='Week12Independent';end
    end
    labels(k)=trials(k).label;
end
if n~=size(R.X,1)
    error('ME3310:Export','GUI trial list does not match analysis. Re-run analysis.');
end
sourceFiles=string(paths);
originalTrialID=(1:n)';
classNames=repmat("Confusing",n,1);classNames(labels==1)="Target";
manifest=table(originalTrialID,sourceFiles,string(roles),classNames,labels, ...
    'VariableNames',{'TrialID','OriginalMAT','Role','Class','TargetIs1'});

% Audit record retained from original import (if available).
if isfield(R,'audit') && height(R.audit)==n
    manifest=[manifest,R.audit];
end
writetable(manifest,[base '_trial_manifest.csv']);
fNames=arrayfun(@(k)sprintf('F%02d',k),1:16,'UniformOutput',false);
featTable=array2table(R.X,'VariableNames',fNames);
writetable([manifest(:,{'TrialID','Role','Class'}) featTable],...
    [base '_trial_features.csv']);
writetable(R.dev,[base '_training_comparison.csv']);
writetable(R.hold,[base '_independent_comparison.csv']);

% Fisher per-feature ranking from the original DEVELOPMENT training set.
% For Week 12, this table comes from Week 11 when present in modelBundle.
if ~isempty(R.fisherTable)
    writetable(R.fisherTable,[base '_fisher_features.csv']);
elseif isfield(modelBundle,'fisherTraining') && ~isempty(modelBundle.fisherTraining)
    writetable(modelBundle.fisherTraining,[base '_fisher_features.csv']);
end

% One model x one actual trial: predictions, scores and error type.
repeatedTrial=[];repeatedDim=[];predicted=[];decisionScore=[];
trueLabel=[];outcome={};rolePred={};
for i=1:numel(R.models)
    [p,s]=ME3310_IMU_Core('predict',R.models(i),R.X);
    for k=1:n
        repeatedTrial(end+1,1)=k; %#ok<AGROW>
        repeatedDim(end+1,1)=R.models(i).dimension; %#ok<AGROW>
        predicted(end+1,1)=p(k); %#ok<AGROW>
        decisionScore(end+1,1)=s(k); %#ok<AGROW>
        trueLabel(end+1,1)=labels(k); %#ok<AGROW>
        rolePred{end+1,1}=roles{k}; %#ok<AGROW>
        if p(k)==1 && labels(k)==1,o='TP';
        elseif p(k)==0 && labels(k)==0,o='TN';
        elseif p(k)==1,o='FP';
        else,o='FN';end
        outcome{end+1,1}=o; %#ok<AGROW>
    end
end
predTable=table(repeatedTrial,repeatedDim,string(rolePred),trueLabel,...
    predicted,decisionScore,string(outcome), ...
    'VariableNames',{'TrialID','Dimension','Role','TrueTarget1', ...
    'PredictedTarget1','DecisionScore','Outcome'});
writetable(predTable,[base '_trial_predictions.csv']);

% Preserve every original MAT file without renaming, and avoid collisions
% across separate directories by prepending the manifest trial ID.
rawFolder=[base '_source_MAT'];
if ~exist(rawFolder,'dir'),mkdir(rawFolder);end
archiveFiles=cell(n,1);
for k=1:n
    [~,b,e]=fileparts(paths{k});
    archived=sprintf('trial_%03d_%s%s',k,b,e);
    dest=fullfile(rawFolder,archived);
    [ok,reason]=copyfile(paths{k},dest);
    if ~ok
        error('ME3310:ExportCopy','Cannot copy source trial: %s (%s)',paths{k},reason);
    end
    archiveFiles{k}=archived;
end

if nargin>=5 && ~isempty(axTop) && ishandle(axTop)
    try,saveas(ancestor(axTop,'figure'),[base '_dashboard.png']);
    catch,warning('ME3310:Figure','Unable to export dashboard screenshot.');end
end

% Human-readable TXT: both technical model and data provenance.
metadataPath=[base '_metadata.txt'];
[fid,err]=fopen(metadataPath,'wt');
if fid<0,error('ME3310:Metadata','Unable to create metadata TXT: %s',err);end
closer=onCleanup(@() fclose(fid)); %#ok<NASGU>
fl=@(s) fprintf(fid,'%s\n',s);
fl('ME 3310 EXPERIMENTAL METHODS I | IMU MOTION DETECTION');
fl('HUMAN-READABLE EXPERIMENT + MACHINE-LEARNING METADATA');
fl(repmat('=',1,76));
fprintf(fid,'Exported: %s (local computer time)\n',createdAt);
fprintf(fid,'Analysis stage: %s\n',mode);
fl('Sensor: PocketLab Voyager IMU (original MAT recordings)');
fl('Classes: 1=Target Motion; 0=Confusing Motion');
fl('Independent observation unit: ONE original MAT recording');
fl('Sliding/overlapping windows within a recording are NOT independent trials.');
fl('');
fl('[STUDENT EXPERIMENTAL DESIGN NOTES]');
if isfield(R,'notes'),ns=R.notes;
elseif isfield(modelBundle,'currentNotes'),ns=modelBundle.currentNotes;
elseif isfield(modelBundle,'notes'),ns=modelBundle.notes;
else,ns=struct();end
if ~isempty(fieldnames(ns))
    fields=fieldnames(ns);
    for k=1:numel(fields)
        fprintf(fid,'%s: %s\n',fields{k},char(string(ns.(fields{k}))));
    end
else
    fl('No experimental notes were entered in the GUI.');
end
fl('');
fl('[MEASUREMENT + FEATURE EXTRACTION SETTINGS]');
fprintf(fid,'Feature profile: %s\n',R.cfg.profile);
fprintf(fid,'Window: %.6f seconds\n',R.cfg.windowSeconds);
fprintf(fid,'Hop: %.6f seconds\n',R.cfg.hopSeconds);
fprintf(fid,'Welch PSD Hamming segment: %.6f seconds, 50%% overlap\n',R.cfg.psdSeconds);
fprintf(fid,'Original PSD band (feature 2): %.3f to %.3f Hz\n',R.cfg.originalBandHz);
for b=1:size(R.cfg.extraBands,1)
    fprintf(fid,'Additional PSD band %d: %.3f to %.3f Hz\n',b,...
        R.cfg.extraBands(b,1),R.cfg.extraBands(b,2));
end
fprintf(fid,'Trial sampling rates: min %.4f Hz; max %.4f Hz\n',min(R.fs),max(R.fs));
if isfield(modelBundle,'developmentFsRange')
    fprintf(fid,'Frozen development-set Fs range: %.4f - %.4f Hz\n', ...
        modelBundle.developmentFsRange(1),modelBundle.developmentFsRange(2));
end
fl('Sampling rates computed from median timestamp differences, not assumed 20 Hz.');
fl('No automatic unit conversion; consult meta.Units in source MAT.');
fl(['Preprocessing: mild timestamp irregularity may be explicitly ' ...
    'linearly interpolated; unacceptable gaps cause an error.']);
if isfield(R.cfg,'note'),fprintf(fid,'Profile note: %s\n',R.cfg.note);end
fl('');
fl('[FEATURE DEFINITIONS AND PRIORITY]');
for k=1:16
    fprintf(fid,'F%02d: %s\n',k,R.cfg.names{k});
end
fprintf(fid,'Student feature ranking (1st to 16th): %s\n',sprintf('%d ',R.rank));
fl('For 2/4/8/12/16D models, use the first d features in that ranking.');
fl('Each 16D trial feature = mean of within-trial overlapping window features.');
fl('');
fl('[TRIAL MANIFEST + ARCHIVED RAW DATA]');
for k=1:n
    fprintf(fid,'Trial %03d | %s | %s | %s | Archived: %s\n',...
        k,roles{k},char(classNames(k)),paths{k},archiveFiles{k});
    if isfield(R,'audit') && height(R.audit)>=k
        a=R.audit;
        fprintf(fid,'     fs %.4f Hz; duration %.3f sec; windows %d; resampled %d; accel [%s], gyro [%s]\n',...
            a.SampleRateHz(k),a.DurationSeconds(k),a.NumWindows(k),...
            a.Resampled(k),char(a.AccelUnits(k)),char(a.GyroUnits(k)));
    end
end
fl('');
fl('[UNIVARIATE FISHER SCORES: DEVELOPMENT-SET ONLY]');
fis=R.fisherScores;
if all(~isfinite(fis)) && isfield(modelBundle,'fisherScores')
    fis=modelBundle.fisherScores;
end
for k=1:16
    if isfinite(fis(k))
        fprintf(fid,'F%02d Fisher = %.9g\n',k,fis(k));
    else
        fprintf(fid,'F%02d Fisher = undefined or not available\n',k);
    end
end
fl('Score convention: (Target mean - Confusing mean)^2 / (Target variance + Confusing variance).');
fl('Higher is in-sample trial separability, NOT proof of new-trial accuracy.');
fl('');
fl('[ORIGINAL TRAINING MODEL PROVENANCE]');
if isfield(modelBundle,'savedAt'),fprintf(fid,'Training date: %s\n',char(modelBundle.savedAt));end
if isfield(modelBundle,'trainingFiles')
    for ii=1:numel(modelBundle.trainingFiles)
        fprintf(fid,'Training file %02d: %s\n',ii,char(modelBundle.trainingFiles{ii}));
    end
end
if isfield(modelBundle,'baselineFiles')
    for ii=1:numel(modelBundle.baselineFiles)
        fprintf(fid,'Week 11 baseline file %02d: %s\n',ii,char(modelBundle.baselineFiles{ii}));
    end
end
fl('');
fl('[LINEAR CLASSIFIER MODELS: FROZEN TRAINING PARAMETERS]');
fl('Model family: standardized nearest-centroid linear classifier.');
fl('z_j = (feature_j - trainingCenter_j) / trainingScale_j');
fl('decisionScore = z * w + b; decisionScore >= 0 predicts Target.');
fl('The same algorithm, with a student-ranked feature subset, is used in every dimension.');
for i=1:numel(R.models)
    m=R.models(i);
    fprintf(fid,'\n--- %d DIMENSIONS ---\n',m.dimension);
    fprintf(fid,'Feature indices: %s\n',sprintf('%d ',m.indices));
    fprintf(fid,'Training Target count: %d; Confusing count: %d\n',m.nTarget,m.nConfusing);
    fprintf(fid,'Training mean: %s\n',joinNumbers(m.center));
    fprintf(fid,'Training scale: %s\n',joinNumbers(m.scale));
    fprintf(fid,'Linear weights (w): %s\n',joinNumbers(m.w));
    fprintf(fid,'Linear intercept (b): %.12g\n',m.b);
    fprintf(fid,'Target class centroid in z-space: %s\n',joinNumbers(m.targetCentroid));
    fprintf(fid,'Confusing class centroid in z-space: %s\n',joinNumbers(m.confusingCentroid));
    fprintf(fid,'Training projected Fisher criterion: %.9g\n',m.fisherProjected);
end
fl('');
fl('[CLASSIFIER PERFORMANCE: ORIGINAL-TRIAL LEVEL]');
for k=1:height(R.dev)
    d=R.dev.Dimension(k);
    nTraining=R.models(k).nTarget+R.models(k).nConfusing;
    fprintf(fid,'D=%2d | training n=%d, accuracy %.3f%%, TP=%d FN=%d TN=%d FP=%d\n',...
        d,nTraining,R.dev.AccuracyPct(k),...
        R.dev.TP(k),R.dev.FN(k),R.dev.TN(k),R.dev.FP(k));
    fprintf(fid,'     evaluation n=%d, accuracy %.3f%%, TP=%d FN=%d TN=%d FP=%d\n',...
        sum(R.holdout),R.hold.AccuracyPct(k),...
        R.hold.TP(k),R.hold.FN(k),R.hold.TN(k),R.hold.FP(k));
end
fl('');
fl('[OUTPUT FILES]');
fprintf(fid,'Model + analysis MAT: %s\n',matFile);
fprintf(fid,'Feature matrix CSV: %s\n',[base '_trial_features.csv']);
fprintf(fid,'Trial manifest CSV: %s\n',[base '_trial_manifest.csv']);
fprintf(fid,'Per-trial predictions CSV: %s\n',[base '_trial_predictions.csv']);
fprintf(fid,'Training comparison CSV: %s\n',[base '_training_comparison.csv']);
fprintf(fid,'Independent comparison CSV: %s\n',[base '_independent_comparison.csv']);
fprintf(fid,'Raw MAT copies folder: %s\n',rawFolder);
fl('');
fl('[LIMITATIONS AND ENGINEERING INTERPRETATION]');
fl('1. The 2D/4D/8D/12D/16D comparisons share the same original trials.');
fl('2. A very small holdout set produces coarse, unstable accuracy estimates.');
fl('3. Fisher scores and training accuracy are descriptive, not independent validation.');
fl('4. Fitting, ranking, or choosing dimensions after examining holdout results');
fl('   turns the holdout into development data; new trials are needed to validate.');
fl('5. For Week 12, apply the unchanged Week 11 model to new independent recordings.');
fl('6. A revised classifier needs further independent test data.');
fl('7. Feature bands above Nyquist are never generated or silently set to zero.');
fl('8. These outputs do not establish motion-transition detection latency or performance');
fl('   across different people, placements, or environments without appropriate tests.');
fl('');
fl('END OF METADATA');

outputs=struct('modelMAT',matFile,'metadataTXT',metadataPath, ...
    'featuresCSV',[base '_trial_features.csv'], ...
    'predictionsCSV',[base '_trial_predictions.csv'], ...
    'rawDataFolder',rawFolder);
end

function s=joinNumbers(values)
values=values(:)';
c=arrayfun(@(v)sprintf('%.12g',v),values,'UniformOutput',false);
s=strjoin(c,', ');
end
