function ME3310_selftest()
% Automated MATLAB checks against explicitly SYNTHETIC demo measurements.
% Run ME3310_selftest; MATLAB itself is required (not executed on delivery).
ME3310_generate_demo();
root=fullfile(fileparts(mfilename('fullpath')),'DEMO_SYNTHETIC_NOT_EXPERIMENTAL_DATA');
cfg=ME3310_IMU_Core('config','PocketLab_20Hz');
X=zeros(6,16);y=[ones(3,1);zeros(3,1)];
paths=cell(6,1);
for k=1:6
    if k<=3,lab='Target';rep=k;
    else,lab='Confusing';rep=k-3;end
    paths{k}=fullfile(root,sprintf('SYNTH_%s_%02d.mat',lab,rep));
    tr=ME3310_IMU_Core('load',paths{k},cfg);
    assert(abs(tr.fs-20)<1e-9,'Sampling rate error');
    assert(tr.n==240 && numel(tr.features)==16,'Trial extraction error');
    X(k,:)=tr.features;
end
train=[1 2 4 5];test=[3 6];
[scores,ft]=ME3310_IMU_Core('fisher',X(train,:),y(train),cfg.names);
assert(numel(scores)==16 && height(ft)==16,'Fisher count error');
models=ME3310_IMU_Core('fit',X(train,:),y(train),1:16);
assert(isequal([models.dimension],[2 4 8 12 16]),'Classifier dimensions error');
[dev,~]=ME3310_IMU_Core('evaluate',models,X(train,:),y(train),'Training');
[ind,~]=ME3310_IMU_Core('evaluate',models,X(test,:),y(test),'Heldout');
assert(height(dev)==5 && height(ind)==5,'Evaluation table error');
assert(strcmp(dev.Properties.VariableNames{1},'Dimension'), ...
    'Summary table labels have changed unexpectedly');
[~,heldoutDetails]=ME3310_IMU_Core('evaluate',models,X(test,:),y(test),'Heldout');
assert(strcmp(heldoutDetails{1}.Properties.VariableNames{1},'TrialIndex'), ...
    'MATLAB table must not use reserved dimension name Row');
assert(all(dev.AccuracyPct>=0 & dev.AccuracyPct<=100));
assert(all(ind.AccuracyPct>=0 & ind.AccuracyPct<=100));
% Verify native PocketLab t/data/info MAT files match canonical features.
src=load(paths{1},'t','accel','gyro');
t=src.t; data=struct('acceleration',src.accel,'gyroscope',src.gyro);
info=struct('SampleCount',numel(t)); %#ok<NASGU>
nativePath=fullfile(root,'SYNTH_native_PocketLab_live.mat');
save(nativePath,'t','data','info');
native=ME3310_IMU_Core('load',nativePath,cfg);
canonical=ME3310_IMU_Core('load',paths{1},cfg);
assert(isequal(size(native.acc),[numel(t) 3]) && ...
    isequal(size(native.gyro),[numel(t) 3]));
assert(max(abs(native.features-canonical.features))<1e-12, ...
    'Native PocketLab import must match canonical features');
% Missing gyro is an error, not a silently fabricated zero signal.
data=rmfield(data,'gyroscope');
missingPath=fullfile(root,'SYNTH_missing_gyro_live.mat');
save(missingPath,'t','data','info');
try
    ME3310_IMU_Core('load',missingPath,cfg);
    error('Expected missing-gyro guard did not trigger.');
catch ME
    assert(strcmp(ME.identifier,'ME3310:MATSchema'), ...
        'Unexpected missing-gyro test failure: %s',ME.message);
end
% Verify that canonical USC-HAD 100Hz feature profile rejects 20Hz data.
try
    ME3310_IMU_Core('load',paths{1},'USC_HAD_100Hz');
    error('Expected Nyquist guard did not trigger.');
catch ME
    assert(strcmp(ME.identifier,'ME3310:Nyquist'),'Unexpected test failure: %s',ME.message);
end
fprintf('ME3310 synthetic self-test PASSED (MATLAB).\n');
disp(ind);
end
