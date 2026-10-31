function varargout = ME3310_IMU_Core(action, varargin)
% ME3310_IMU_CORE  Back end for Week 11/12 IMU Motion Analyzer.
% Works with MATLAB R2021b or newer; no add-on toolboxes required.
% One original MAT recording -> one 16-feature vector (average of windows).
%
% Commands:
%   cfg = ME3310_IMU_Core('config', profile)
%   trial = ME3310_IMU_Core('load', path, profileOrConfig)
%   [scores,T] = ME3310_IMU_Core('fisher', Xdev, ydev, names)
%   models = ME3310_IMU_Core('fit', Xdev, ydev, rank)
%   [summary,detail] = ME3310_IMU_Core('evaluate',models,X,y,split)
%   [pred,score] = ME3310_IMU_Core('predict',model,X)
%
% LABELS: Target=1, Confusing=0. Trial labels are always assigned explicitly
% by the user of the GUI, NEVER inferred from a filename or metadata.

switch lower(char(action))
    case 'config'
        varargout{1} = config(varargin{1});
    case 'load'
        varargout{1} = loadTrial(varargin{1},varargin{2});
    case 'fisher'
        [varargout{1},varargout{2}] = fisherFeatures(varargin{1},varargin{2},varargin{3});
    case 'fit'
        varargout{1} = fitModels(varargin{1},varargin{2},varargin{3});
    case 'predict'
        [varargout{1},varargout{2}] = predictModel(varargin{1},varargin{2});
    case 'evaluate'
        [varargout{1},varargout{2}] = evaluateModels(varargin{1},varargin{2},varargin{3},varargin{4});
    otherwise
        error('ME3310:Action','Unknown core action: %s',char(action));
end
end

function cfg = config(profile)
profile=char(profile);
cfg.profile=profile;
cfg.windowSeconds=3.0;
cfg.hopSeconds=0.5;
cfg.psdSeconds=2.0;
cfg.resampleIrregular=true; % interpolate only modest timestamp jitter (<1.5x median gap)
cfg.originalBandHz=[0.8 3.0];
cfg.dims=[2 4 8 12 16];
cfg.names={...
    '01 Accel magnitude STD', ...
    '02 Accel PSD 0.8-3.0 Hz', ...
    '03 Gyro X RMS', ...
    '04 Gyro Y RMS', ...
    '05 Gyro Z RMS', ...
    '06 Gyro X mean', ...
    '07 Gyro Y mean', ...
    '08 Gyro Z mean'};
if strcmp(profile,'PocketLab_20Hz')
    % Original USC-HAD bands above the PocketLab Nyquist frequency are
    % REPLACED explicitly, not interpreted as 0 or artificially extrapolated.
    cfg.extraBands=[0.3 0.8;0.8 1.5;1.5 3;3 5;5 8];
    cfg.names=[cfg.names,{
        '09 Accel PSD 0.3-0.8 Hz',...
        '10 Accel PSD 0.8-1.5 Hz',...
        '11 Accel PSD 1.5-3.0 Hz',...
        '12 Accel PSD 3.0-5.0 Hz',...
        '13 Accel PSD 5.0-8.0 Hz',...
        '14 Accel magnitude RMS',...
        '15 Gyro magnitude RMS',...
        '16 Accel magnitude range'}];
    cfg.minimumFs=16.01; % 8 Hz band must be below Nyquist.
    cfg.note=['Adapted 20-Hz feature set. Original USC-HAD features 14-16 ' ...
        'were 8-12, 12-20, and 20-40 Hz PSD power. These are physically ' ...
        'unobservable at 20 Hz and are replaced by three time-domain features.'];
elseif strcmp(profile,'USC_HAD_100Hz')
    cfg.extraBands=[0.3 0.8;0.8 1.5;1.5 3;3 5;5 8;8 12;12 20;20 40];
    cfg.names=[cfg.names,{
        '09 Accel PSD 0.3-0.8 Hz',...
        '10 Accel PSD 0.8-1.5 Hz',...
        '11 Accel PSD 1.5-3.0 Hz',...
        '12 Accel PSD 3.0-5.0 Hz',...
        '13 Accel PSD 5.0-8.0 Hz',...
        '14 Accel PSD 8.0-12.0 Hz',...
        '15 Accel PSD 12.0-20.0 Hz',...
        '16 Accel PSD 20.0-40.0 Hz'}];
    cfg.minimumFs=80.01;
    cfg.note='Original USC-HAD 100-Hz 16-feature definitions.';
else
    error('ME3310:Profile','Choose PocketLab_20Hz or USC_HAD_100Hz.');
end
assert(numel(cfg.names)==16,'Internal feature definition error.');
end

function tr=loadTrial(path,profile)
if ~isfile(path),error('ME3310:MissingFile','File not found: %s',path);end
vars=whos('-file',path);
names={vars.name};
isCanonical=all(ismember({'t','accel','gyro'},names));
isPocketLab=all(ismember({'t','data'},names));
if isCanonical
    req={'t','accel','gyro'};
    if ismember('meta',names),req{end+1}='meta';end
    S=load(path,req{:});
    t=double(S.t(:));
    a=double(S.accel);
    g=double(S.gyro);
elseif isPocketLab
    % Native PocketLab Voyager 2 Real-Time / decoded Memory MAT export:
    %   t [Nx1], data.acceleration [Nx3], data.gyroscope [Nx3], info
    % Do not fabricate a missing channel or interpret names as labels.
    req={'t','data'};
    if ismember('info',names),req{end+1}='info';end
    S=load(path,req{:});
    if ~isstruct(S.data) || ...
            ~all(isfield(S.data,{'acceleration','gyroscope'}))
        error('ME3310:MATSchema', ...
            ['PocketLab MAT needs BOTH data.acceleration and ' ...
             'data.gyroscope. Re-record with both sensor groups selected.']);
    end
    t=double(S.t(:));
    a=double(S.data.acceleration);
    g=double(S.data.gyroscope);
else
    error('ME3310:MATSchema', ...
        ['Supported MAT layouts: (t,accel,gyro) OR PocketLab ' ...
         '(t,data.acceleration,data.gyroscope). Found: %s'], ...
         strjoin(names,', '));
end
n=numel(t);
if n<8 || any(~isfinite(t)) || any(diff(t)<=0)
    error('ME3310:Time','t must have >=8 finite, strictly increasing samples.');
end
if ~isequal(size(a),[n 3]) || ~isequal(size(g),[n 3]) || ...
        any(~isfinite(a(:))) || any(~isfinite(g(:)))
    error('ME3310:Channels','accel and gyro must both be finite Nx3 arrays.');
end
dt=diff(t);
med=median(dt);
fs=1/med;
if isstruct(profile)
    cfg=profile;
else
    cfg=config(profile);
end
resampled=false;
if any(abs(dt-med)>0.05*med)
    if ~cfg.resampleIrregular || any(dt>1.5*med)
        error('ME3310:Jitter',[ ...
          'Timestamp jitter/dropout detected. PSD requires uniform sampling. ' ...
          'Large gaps cannot be silently filled. Re-record or inspect first.']);
    end
    % Explicit preprocessing for mild BLE timestamp jitter: interpolation.
    tq=(t(1):med:t(end))';
    a=interp1(t,a,tq,'linear');g=interp1(t,g,tq,'linear');
    t=tq;n=numel(t);resampled=true;
    warning('ME3310:Resampled','Mild timestamp jitter: linearly resampled %s at %.3f Hz.',path,fs);
end
if fs<=cfg.minimumFs
    error('ME3310:Nyquist',[ ...
        'Sampling rate %.2f Hz cannot resolve this 16-feature profile. ' ...
        'Required Fs > %.2f Hz; do not invent out-of-band power.'],fs,cfg.minimumFs);
end
if numel(t)<round(cfg.windowSeconds*fs)
    error('ME3310:Duration', ...
        'Recording needs at least %d samples for a %.2f-second analysis window.', ...
        round(cfg.windowSeconds*fs),cfg.windowSeconds);
end
tr=struct();
tr.path=char(path);
[~,nm,ext]=fileparts(path);
tr.name=[nm ext];
tr.t=t-t(1);
tr.acc=a;
tr.gyro=g;
tr.fs=fs;
tr.duration=tr.t(end);
tr.n=n;
tr.resampled=resampled;
tr.meta=struct();
if isfield(S,'meta') && isstruct(S.meta)
    tr.meta=S.meta;
end
if isPocketLab && ~isCanonical
    tr.meta.SourceFormat='PocketLab Voyager 2 native MAT';
    tr.meta.TimestampNote=['Nominal stream time from driver; ' ...
        'not verified device hardware timestamps.'];
    if isfield(S,'info') && isstruct(S.info)
        if isfield(S.info,'SampleCount')
            tr.meta.DriverSampleCount=S.info.SampleCount;
        end
        % The PocketLab driver writes sensor names and units into info,
        % whereas older student-format files use meta.Units.
        if isfield(S.info,'Sensors') && isfield(S.info,'Units')
            sensorNames=lower(string(S.info.Sensors(:)));
            sensorUnits=string(S.info.Units(:));
            if numel(sensorNames)==numel(sensorUnits)
                ia=find(sensorNames=="acceleration",1);
                ig=find(sensorNames=="gyroscope",1);
                if ~isempty(ia) && ~isempty(ig)
                    tr.meta.Units=struct('accel',char(sensorUnits(ia)), ...
                        'gyro',char(sensorUnits(ig)));
                end
            end
        end
    end
end
tr.unitsAccel='not specified';tr.unitsGyro='not specified';
if isfield(tr.meta,'Units') && isstruct(tr.meta.Units)
    if isfield(tr.meta.Units,'accel'),tr.unitsAccel=char(string(tr.meta.Units.accel));end
    if isfield(tr.meta.Units,'gyro'),tr.unitsGyro=char(string(tr.meta.Units.gyro));end
end
tr.features=extractFeatures(tr,cfg);
end

function feat=extractFeatures(tr,cfg)
fs=tr.fs;
N=round(cfg.windowSeconds*fs);
H=max(1,round(cfg.hopSeconds*fs));
if N>tr.n,error('ME3310:Window','Recording is shorter than one analysis window.');end
kmax=floor((tr.n-N)/H)+1;
if kmax<1,error('ME3310:Window','No complete window found.');end
F=zeros(kmax,16);
for k=1:kmax
    idx=(1+(k-1)*H):(N+(k-1)*H);
    aa=tr.acc(idx,:); gg=tr.gyro(idx,:);
    amag=sqrt(sum(aa.^2,2));
    dynamic=amag-mean(amag);
    [px,f]=welchPsd(dynamic,fs,cfg.psdSeconds);
    band=bandArea(px,f,cfg.originalBandHz);
    pExtra=zeros(1,size(cfg.extraBands,1));
    for b=1:numel(pExtra)
        pExtra(b)=bandArea(px,f,cfg.extraBands(b,:));
    end
    % First eight features EXACTLY retain the lecture definitions.
    base=[std(amag,0),band,sqrt(mean(gg.^2,1)),mean(gg,1)];
    if strcmp(cfg.profile,'PocketLab_20Hz')
        extensions=[sqrt(mean(amag.^2)), ...
            sqrt(mean(sum(gg.^2,2))), max(amag)-min(amag)];
        F(k,:)=[base,pExtra,extensions];
    else
        F(k,:)=[base,pExtra];
    end
end
feat=mean(F,1); % one vector PER ORIGINAL TRIAL (not per window)
if any(~isfinite(feat))
    error('ME3310:Feature','Nonfinite feature detected; inspect measurement quality.');
end
end

function [P,f]=welchPsd(x,fs,seconds)
% Welch PSD (Hamming, 50% overlap, one-sided); no Signal Processing Toolbox.
x=double(x(:));
segN=min(numel(x),max(8,round(seconds*fs)));
step=max(1,segN-floor(segN/2));
nfft=max(512,2^nextpow2(segN));
h=.54-.46*cos(2*pi*(0:segN-1)'/(segN-1));
U=sum(h.^2);
nAvg=0;
P=zeros(nfft/2+1,1);
for first=1:step:(numel(x)-segN+1)
    xx=x(first:first+segN-1);
    xx=xx-mean(xx);
    z=fft(xx.*h,nfft);
    p=abs(z(1:nfft/2+1)).^2/(fs*U);
    p(2:end-1)=2*p(2:end-1);
    P=P+p;
    nAvg=nAvg+1;
end
P=P/nAvg;
f=(0:nfft/2)'*fs/nfft;
end

function power=bandArea(P,f,band)
if band(2)>=f(end)
    error('ME3310:Nyquist','A PSD frequency band exceeds the Nyquist frequency.');
end
inside=(f>band(1) & f<band(2));
fi=[band(1);f(inside);band(2)];
pi=interp1(f,P,fi,'linear');
power=trapz(fi,pi);
end

function [scores,T]=fisherFeatures(X,y,featNames)
checkData(X,y);
if sum(y==1)<2 || sum(y==0)<2
    error('ME3310:FisherN','Fisher estimates require >=2 independent development trials per class.');
end
T1=X(y==1,:); C0=X(y==0,:);
mu1=mean(T1,1);mu0=mean(C0,1);
s1=std(T1,0,1);s0=std(C0,0,1);
den=s1.^2+s0.^2;
scores=nan(1,size(X,2));
valid=den>1e-14*max(1,max(den));
scores(valid)=(mu1(valid)-mu0(valid)).^2./den(valid);
T=table((1:size(X,2))',string(featNames(:)),mu1',s1',mu0',s0',scores',...
    'VariableNames',{'Index','Feature','TargetMean','TargetSTD', ...
    'ConfusingMean','ConfusingSTD','FisherScore'});
end

function models=fitModels(X,y,rank)
checkData(X,y);
if sum(y==1)<2 || sum(y==0)<2
    error('ME3310:TrainingN','At least two independent training trials per class are required.');
end
if ~isequal(sort(rank(:))',(1:16))
    error('ME3310:FeatureRank','Rank must be a permutation of feature numbers 1-16.');
end
D=[2 4 8 12 16];
models=repmat(struct('dimension',0,'indices',[],'center',[],'scale',[], ...
    'w',[],'b',[],'targetCentroid',[],'confusingCentroid',[], ...
    'fisherProjected',nan,'nTarget',0,'nConfusing',0),1,numel(D));
for i=1:numel(D)
    idx=rank(1:D(i));
    A=X(:,idx);
    center=mean(A,1);
    sd=std(A,0,1);
    sd(sd<1e-12)=1; % Zero-range directions contribute zero to w.
    Z=(A-center)./sd;
    c1=mean(Z(y==1,:),1);
    c0=mean(Z(y==0,:),1);
    w=(c1-c0)';
    b=-0.5*((c1+c0)*w);
    score=Z*w+b;
    v1=var(score(y==1),0);v0=var(score(y==0),0);
    jm=nan;
    if v1+v0>1e-14
        jm=(mean(score(y==1))-mean(score(y==0)))^2/(v1+v0);
    end
    models(i).dimension=D(i);
    models(i).indices=idx;
    models(i).center=center;
    models(i).scale=sd;
    models(i).targetCentroid=c1;
    models(i).confusingCentroid=c0;
    models(i).w=w;
    models(i).b=b;
    models(i).fisherProjected=jm;
    models(i).nTarget=sum(y==1);
    models(i).nConfusing=sum(y==0);
end
end

function [yp,score]=predictModel(model,X)
if size(X,2)~=16,error('ME3310:Predict','Prediction input must have all 16 features.');end
A=X(:,model.indices);
Z=(A-model.center)./model.scale;
score=Z*model.w+model.b;
yp=double(score>=0);
end

function [summary,details]=evaluateModels(models,X,y,split)
checkData(X,y);
if nargin<4,split='Independent';end
n=numel(models);
accuracy=zeros(n,1);balanced=nan(n,1);
TP=zeros(n,1);FN=zeros(n,1);TN=zeros(n,1);FP=zeros(n,1);
fisher=nan(n,1);d=zeros(n,1);
details=cell(n,1);
for k=1:n
    [yp,score]=predictModel(models(k),X);
    d(k)=models(k).dimension;
    TP(k)=sum(yp==1 & y==1);FN(k)=sum(yp==0 & y==1);
    TN(k)=sum(yp==0 & y==0);FP(k)=sum(yp==1 & y==0);
    accuracy(k)=100*mean(yp==y);
    if TP(k)+FN(k)>0 && TN(k)+FP(k)>0
        balanced(k)=50*(TP(k)/(TP(k)+FN(k))+TN(k)/(TN(k)+FP(k)));
    end
    fisher(k)=models(k).fisherProjected;
    details{k}=table((1:numel(y))',y(:),yp(:),score(:),...
        'VariableNames',{'TrialIndex','TrueTarget1','PredictedTarget1','DecisionScore'});
end
summary=table(d,accuracy,balanced,TP,FN,TN,FP,fisher, ...
    'VariableNames',{'Dimension','AccuracyPct','BalancedAccuracyPct',...
    'TP','FN','TN','FP','TrainProjectedFisher'});
summary.Properties.Description=char(split);
end

function checkData(X,y)
if ~isnumeric(X) || size(X,2)~=16 || any(~isfinite(X(:)))
    error('ME3310:Data','Feature matrix must be finite N x 16.');
end
if ~isnumeric(y) || numel(y)~=size(X,1) || ...
        ~all(ismember(y(:),[0 1]))
    error('ME3310:Labels','Each trial needs a binary label (Target=1, Confusing=0).');
end
y=y(:);
end
