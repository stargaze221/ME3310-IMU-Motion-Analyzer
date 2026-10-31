function ME3310_IMU_Analyzer()
% ME3310_IMU_ANALYZER | Week 11 & 12 PocketLab MATLAB Motion Lab
% Run by entering ME3310_IMU_Analyzer in MATLAB command window.
% BASE MATLAB ONLY (no Statistics/Signal Processing toolboxes needed).
% Real measurements only. No data are manufactured by this GUI.
% Labels assigned via import buttons; each original recording counts as ONE trial.
% Week 11: choose Train/Holdout BEFORE ranking and fitting.
% Week 12: load saved models and evaluate NEW recordings, without retraining.

names=ME3310_IMU_Core('config','PocketLab_20Hz');
rank=1:16;
trials=struct('path',{},'label',{},'role',{});
R=[]; modelBundle=[]; importedBundle=[];
profileName='PocketLab_20Hz';
notes=struct('TargetMotion','','ConfusingMotion','','SensorPlacement','', ...
    'GroundTruthMethod','','Conditions','','FeatureRationale','', ...
    'NextValidationPlan','');

fig=figure('Name','ME 3310 | IMU Motion Analysis Tool','NumberTitle','off', ...
  'Color',[.96 .97 .985],'Units','normalized', ...
  'Position',[.06 .07 .88 .86],'MenuBar','none','ToolBar','none');

pData=uipanel(fig,'Title','1 | Measurement files and analysis settings', ...
  'FontWeight','bold','Units','normalized','Position',[.012 .56 .36 .43], ...
  'BackgroundColor',[.96 .97 .985]);
mktext(pData,[.03 .875 .35 .075],'Feature profile');
hProfile=uicontrol(pData,'Style','popupmenu','String',{'PocketLab_20Hz','USC_HAD_100Hz'}, ...
  'Units','normalized','Position',[.39 .89 .58 .072], 'Callback',@changeProfile);
mktext(pData,[.03 .79 .32 .07],'Window (s)');
hWindow=uicontrol(pData,'Style','edit','String','3','Units','normalized', ...
  'Position',[.30 .80 .16 .075],'BackgroundColor','white');
mktext(pData,[.51 .79 .27 .07],'Hop (s)');
hHop=uicontrol(pData,'Style','edit','String','0.5','Units','normalized', ...
  'Position',[.80 .80 .15 .075],'BackgroundColor','white');
mkbutton(pData,[.03 .685 .45 .085],'Import TARGET MAT',@(~,~) addFiles(1));
mkbutton(pData,[.52 .685 .45 .085],'Import CONFUSING MAT',@(~,~) addFiles(0));
hTrials=uitable(pData,'Units','normalized','Position',[.03 .27 .94 .39], ...
    'ColumnName',{'Motion','Original MAT file','Role'}, ...
    'ColumnWidth',{85 230 78}, 'ColumnEditable',[false false true], ...
    'ColumnFormat',{'char','char',{'Train','Holdout'}}, ...
    'CellEditCallback',@editTrialRole,'Data',cell(0,3));
mkbutton(pData,[.03 .165 .45 .075],'Fit + Eval (Week 11)',@runFit);
mkbutton(pData,[.52 .165 .45 .075],'Evaluate NEW (Week 12)',@runWeek12);
mkbutton(pData,[.03 .067 .45 .075],'Clear Trial List',@clearTrials);
mkbutton(pData,[.52 .067 .45 .075],'Load Saved Models',@loadModels);

pFeat=uipanel(fig,'Title','2 | Fisher score and student feature ranking', ...
  'FontWeight','bold','Units','normalized','Position',[.012 .06 .36 .48], ...
  'BackgroundColor',[.96 .97 .985]);
hFisherLabel=mktext(pFeat,[.03 .92 .45 .055],'Fisher score (TRAIN only)');
hFisher=uitable(pFeat,'Units','normalized','Position',[.03 .27 .45 .62], ...
  'ColumnName',{'ID','Fisher'},'ColumnWidth',{40 87}, ...
  'Data',[num2cell((1:16)'),repmat({'—'},16,1)]);
mktext(pFeat,[.52 .92 .46 .055],'Feature priority (top N used)');
hRank=uicontrol(pFeat,'Style','listbox','Units','normalized', ...
    'Position',[.52 .27 .45 .62],'String',names.names,'Value',1, ...
    'BackgroundColor','white','FontSize',9);
mkbutton(pFeat,[.03 .16 .45 .075],'Rank by Fisher (train)',@rankByFisher);
mkbutton(pFeat,[.52 .16 .215 .075],'Move UP',@(~,~) moveFeature(-1));
mkbutton(pFeat,[.755 .16 .215 .075],'Move DOWN',@(~,~) moveFeature(1));
mkbutton(pFeat,[.03 .044 .43 .075],'Experiment Notes',@editNotes);
mktext(pFeat,[.50 .015 .47 .14], ...
 'Document motion, sensor placement and ground truth for the metadata export.');

pPlot=uipanel(fig,'Title','3 | Classifier diagnostics (one point = one original trial)', ...
  'FontWeight','bold','Units','normalized','Position',[.39 .06 .598 .93], ...
  'BackgroundColor',[.96 .97 .985]);
hView=uicontrol(pPlot,'Style','popupmenu', ...
  'String',{'2D decision boundary','Fisher score ranking'}, ...
  'Units','normalized','Position',[.04 .916 .45 .057], 'Callback',@(~,~) plotResults());
mkbutton(pPlot,[.745 .916 .235 .057],'Export ML + Metadata',@saveResults);
axTop=axes('Parent',pPlot,'Units','normalized','Position',[.13 .56 .81 .33]);
axBottom=axes('Parent',pPlot,'Units','normalized','Position',[.13 .17 .81 .29]);
hInfo=uicontrol(pPlot,'Style','edit','Max',6,'Min',0,'Enable','inactive', ...
  'Units','normalized','Position',[.04 .013 .94 .127], 'HorizontalAlignment','left', ...
  'BackgroundColor','white','String',{...
   'Import labeled MAT trials. Suggested: 3 Target + 3 Confusing.',...
   'Use Train=2 and Holdout=1 per class. Choose feature ranking before fitting.',...
   'Evaluate new independent Week 12 trials with the saved, unchanged model.'});
refreshRank();

    function h=mkbutton(parent,pos,txt,fn)
        h=uicontrol(parent,'Style','pushbutton','String',txt, ...
            'Units','normalized','Position',pos,'Callback',fn,'FontSize',9);
    end
    function h=mktext(parent,pos,txt)
        h=uicontrol(parent,'Style','text','String',txt,'Units','normalized', ...
            'Position',pos,'BackgroundColor',get(parent,'BackgroundColor'), ...
            'HorizontalAlignment','left','FontSize',9);
    end
    function refreshRank()
        allNames=ME3310_IMU_Core('config',profileName);
        strings=allNames.names(rank);
        set(hRank,'String',strings,'Value',min(max(1,get(hRank,'Value')),16));
    end
    function editNotes(~,~)
        fields=fieldnames(notes);
        labels={'Target motion definition','Confusing motion definition', ...
            'Sensor placement and orientation','Independent ground-truth method', ...
            'Experimental conditions / subject','Why choose these features?', ...
            'Proposed next validation experiment'};
        defaults=cell(numel(fields),1);
        for k=1:numel(fields),defaults{k}=char(notes.(fields{k}));end
        a=inputdlg(labels,'ME 3310 | Experimental Metadata',1,defaults);
        if isempty(a),return;end
        for k=1:numel(fields),notes.(fields{k})=a{k};end
        if ~isempty(R),R.notes=notes;end
        if ~isempty(modelBundle),modelBundle.currentNotes=notes;end
        msg('Experimental notes updated. They will be included in the metadata TXT export.');
    end
    function changeProfile(~,~)
        if get(hProfile,'Value')==1,profileName='PocketLab_20Hz';
        else,profileName='USC_HAD_100Hz';end
        R=[];importedBundle=[];modelBundle=[];rank=1:16;refreshRank();plotResults();
        set(hTrials,'ColumnEditable',[false false true]);
        set(hTrials,'ColumnFormat',{'char','char',{'Train','Holdout'}});
        populateFrozenFisher([],false);
        msg('Profile changed. Re-analyze recordings before fitting a model.');
    end
    function addFiles(label)
        if ~isempty(R)
            warndlg(['Results have already been displayed. Do not change the same ' ...
                'evaluation set or retrain on it. Use Load Saved Models + Evaluate NEW ' ...
                'for Week 12.'],'Frozen experiment');return;
        end
        [ff,folder]=uigetfile('*.mat','Choose original PocketLab trial MAT files', ...
            'MultiSelect','on');
        if isequal(ff,0),return;end
        if ischar(ff),ff={ff};end
        existing={trials.path};
        for i=1:numel(ff)
            path=fullfile(folder,ff{i});
            if any(strcmp(existing,path))
                warndlg(['Already imported: ' ff{i}],'Duplicate file');continue;
            end
            count=sum([trials.label]==label);
            if ~isempty(importedBundle)
                role='New Eval';
            else
                role='Train';
                if count>=2,role='Holdout';end
            end
            trials(end+1)=struct('path',path,'label',label,'role',role); %#ok<AGROW>
            existing{end+1}=path; %#ok<AGROW>
        end
        R=[];refreshTrialTable();plotResults();
        if ~isempty(importedBundle)
            msg(sprintf('%d NEW validation trials loaded; frozen model will not be retrained.',numel(trials)));
        else
            msg(sprintf('%d original trials loaded; confirm class labels and split before analysis.',numel(trials)));
        end
    end
    function refreshTrialTable()
        vals=cell(numel(trials),3);
        for k=1:numel(trials)
            if trials(k).label==1,vals{k,1}='Target';else,vals{k,1}='Confusing';end
            [~,f,e]=fileparts(trials(k).path);vals{k,2}=[f e];
            vals{k,3}=trials(k).role;
        end
        set(hTrials,'Data',vals);
    end
    function editTrialRole(src,ev)
        if ~isempty(importedBundle)
            refreshTrialTable();return; % Week12 uses every imported trial for evaluation.
        end
        if ~isempty(R)
            warndlg('Split identities are frozen after evaluation.','Frozen split');
            refreshTrialTable();return;
        end
        k=ev.Indices(1);
        desired=char(ev.NewData);
        if k>numel(trials) || ~any(strcmp(desired,{'Train','Holdout'}))
            refreshTrialTable();return;
        end
        trials(k).role=desired;R=[];plotResults();
        refreshTrialTable();
    end
    function clearTrials(~,~)
        trials=struct('path',{},'label',{},'role',{});
        R=[];refreshTrialTable();plotResults();msg('Trial list cleared; saved model remains available.');
    end
    function cfg=currentConfig()
        cfg=ME3310_IMU_Core('config',profileName);
        cfg.windowSeconds=str2double(get(hWindow,'String'));
        cfg.hopSeconds=str2double(get(hHop,'String'));
        if ~isfinite(cfg.windowSeconds) || ~isfinite(cfg.hopSeconds) || ...
                cfg.windowSeconds<2 || cfg.windowSeconds>12 || ...
                cfg.hopSeconds<=0 || cfg.hopSeconds>cfg.windowSeconds
            error('ME3310:Settings','Window must be 2-12 s; hop must be >0 and <= window.');
        end
        cfg.psdSeconds=min(2,cfg.windowSeconds);
    end
    function [X,y,roles,fs,audit]=readMeasurements(cfg)
        if isempty(trials),error('ME3310:Trials','Import your MAT files first.');end
        X=zeros(numel(trials),16);
        y=zeros(numel(trials),1);roles=cell(numel(trials),1);
        fs=zeros(numel(trials),1);uA=cell(numel(trials),1);uG=uA;
        duration=zeros(numel(trials),1);nWindows=zeros(numel(trials),1);resampled=false(numel(trials),1);
        eventLabels=cell(numel(trials),1);recordIDs=cell(numel(trials),1);
        for k=1:numel(trials)
            tr=ME3310_IMU_Core('load',trials(k).path,cfg);
            X(k,:)=tr.features;
            y(k)=trials(k).label;
            roles{k}=trials(k).role;
            fs(k)=tr.fs;
            uA{k}=tr.unitsAccel;uG{k}=tr.unitsGyro;
            duration(k)=tr.duration;resampled(k)=tr.resampled;
            nS=round(cfg.windowSeconds*tr.fs);hS=max(1,round(cfg.hopSeconds*tr.fs));
            nWindows(k)=floor((tr.n-nS)/hS)+1;
            eventLabels{k}='';recordIDs{k}='';
            if isfield(tr.meta,'EventLabel')
                eventLabels{k}=char(string(tr.meta.EventLabel));
                if any(strcmpi(eventLabels{k},{'Target','Confusing'}))
                    expected='Target';if y(k)==0,expected='Confusing';end
                    if ~strcmpi(eventLabels{k},expected)
                        error('ME3310:LabelConflict', ...
                            'MAT meta.EventLabel conflicts with the GUI class selection for %s.',tr.name);
                    end
                end
            end
            if isfield(tr.meta,'ID'),recordIDs{k}=char(string(tr.meta.ID));end
        end
        if max(fs)/min(fs)>1.05
            error('ME3310:Rate','Sampling rates differ by >5%% across trials; use a consistent measurement setup.');
        end
        if numel(unique(uA))>1 || numel(unique(uG))>1
            error('ME3310:Units','Inconsistent sensor units among trials. Correct recordings first.');
        end
        audit=table(fs,duration,nWindows,resampled,string(uA),string(uG), ...
            string(recordIDs),string(eventLabels), ...
            'VariableNames',{'SampleRateHz','DurationSeconds','NumWindows', ...
            'Resampled','AccelUnits','GyroUnits','MetadataID','MetadataEventLabel'});
        % Unit labels are retained in the audit and metadata export.
        % Unknown/native gyro units are an interpretation limitation,
        % not a repeated MATLAB warning. Different units still ERROR above.
    end
    function runFit(~,~)
      try
        if ~isempty(importedBundle)
            error('ME3310:Frozen','Week11 model loaded. Choose Evaluate NEW (Week12), not Fit + Eval.');
        end
        if ~isempty(R)
            error('ME3310:Frozen','Already fitted and evaluated on these holdouts. Clear and collect NEW evaluation trials before new model-selection experiments.');
        end
        cfg=currentConfig();[X,y,roles,fs,audit]=readMeasurements(cfg);
        train=strcmp(roles,'Train');test=strcmp(roles,'Holdout');
        if sum(train & y==1)<2 || sum(train & y==0)<2
            error('ME3310:Split','Need >=2 independent TRAIN trials of each motion.');
        end
        if ~any(test),error('ME3310:Split','Reserve independent HOLDOUT trials before fitting.');end
        if ~(any(test & y==1) && any(test & y==0))
            error('ME3310:Split','Reserve at least one HOLDOUT trial of each motion.');
        end
        [scores,ft]=ME3310_IMU_Core('fisher',X(train,:),y(train),cfg.names);
        fsTable=[num2cell((1:16)'),num2cell(round(scores(:)*1000)/1000)];
        for j=1:16
            if ~isfinite(scores(j)),fsTable{j,2}='undefined';end
        end
        set(hFisher,'Data',fsTable);
        models=ME3310_IMU_Core('fit',X(train,:),y(train),rank);
        [dev,devDetail]=ME3310_IMU_Core('evaluate',models,X(train,:),y(train),'Development');
        [hold,holdDetail]=ME3310_IMU_Core('evaluate',models,X(test,:),y(test),'Preliminary held-out');
        R=struct('models',models,'X',X,'y',y,'train',train,'holdout',test, ...
            'fisherScores',scores,'fisherTable',ft,'dev',dev,'hold',hold, ...
            'devDetail',{devDetail},'holdDetail',{holdDetail},'cfg',cfg, ...
            'rank',rank,'fs',fs,'audit',audit,'notes',notes);
        modelBundle=struct('models',models,'config',cfg,'rank',rank, ...
            'featureNames',{cfg.names},'trainingFiles',{ {trials(train).path} }, ...
            'baselineFiles',{ {trials.path} },'trainingSummary',dev, ...
            'heldoutSummary',hold,'fisherTraining',ft, ...
            'fisherScores',scores,'notes',notes,'unitAccel',audit.AccelUnits(1), ...
            'unitGyro',audit.GyroUnits(1),'developmentFsRange', ...
            [min(fs(train)) max(fs(train))],'savedAt',char(datetime('now')));
        importedBundle=[];plotResults();
        msg({sprintf(['Week 11: %d TRAIN / %d HOLDOUT trials. ' ...
            'Fisher TRAIN-only; Fs %.2f-%.2f Hz.'], ...
            sum(train),sum(test),min(fs),max(fs)), ...
            sprintf('Sensor units: Accel %s; Gyro %s (native is unverified).', ...
            char(audit.AccelUnits(1)),char(audit.GyroUnits(1))), ...
            'A small holdout is preliminary evidence, not reliability proof.'});
      catch ME
        errordlg(ME.message,'Analysis failed');msg(['ERROR: ' ME.message]);
      end
    end
    function rankByFisher(~,~)
      try
        if ~isempty(importedBundle)
            warndlg('The loaded Week 11 Fisher ranking is frozen; Week 12 is evaluation only.', ...
                'Frozen model');return;
        end
        if ~isempty(R)
            warndlg(['The held-out evaluation has already been viewed. ' ...
                'Do not re-rank using the same holdout. For a new experiment, ' ...
                'clear and acquire NEW independent evaluation trials.'], ...
                'Evaluation already revealed');return;
        end
        cfg=currentConfig();[X,y,roles,~]=readMeasurements(cfg);
        training=strcmp(roles,'Train');
        [scores,~]=ME3310_IMU_Core('fisher',X(training,:),y(training),cfg.names);
        fsTable=[num2cell((1:16)'),num2cell(round(scores(:)*1000)/1000)];
        for j=1:16
            if ~isfinite(scores(j)),fsTable{j,2}='undefined';end
        end
        set(hFisher,'Data',fsTable);
        v=scores;v(~isfinite(v))=-inf;
        [~,rank]=sort(v,'descend');
        refreshRank();plotResults();
        msg('Feature ranking uses ONLY development TRAIN trials; the holdout has not been evaluated.');
      catch ME
        errordlg(ME.message,'Fisher ranking failed');msg(['ERROR: ' ME.message]);
      end
    end
    function moveFeature(dir)
        if ~isempty(importedBundle)
            warndlg('Feature ranking is frozen after loading the Week 11 model.', ...
                'Frozen model');return;
        end
        if ~isempty(R)
            warndlg('Features are locked after viewing holdout results. New independent trials are needed to validate a revised selection.','Frozen selection');return;
        end
        k=get(hRank,'Value');j=k+dir;
        if j<1 || j>16,return;end
        rank([k j])=rank([j k]);
        set(hRank,'Value',j);refreshRank();R=[];plotResults();
        msg('Student ranking updated (no evaluation used). Click Fit + Eval after finalizing.');
    end
    function loadModels(~,~)
        [f,folder]=uigetfile('*.mat','Load saved Week 11 modelBundle');
        if isequal(f,0),return;end
        S=load(fullfile(folder,f),'modelBundle');
        if ~isfield(S,'modelBundle') || ~isfield(S.modelBundle,'models') || ...
                ~isfield(S.modelBundle,'config')
            errordlg('Selected MAT file has no valid modelBundle.','Invalid model');return;
        end
        importedBundle=S.modelBundle;
        if isfield(importedBundle,'notes'),notes=importedBundle.notes;end
        if isfield(importedBundle,'currentNotes'),notes=importedBundle.currentNotes;end
        modelBundle=importedBundle;
        cfg=importedBundle.config;
        profileName=cfg.profile;
        if strcmp(cfg.profile,'PocketLab_20Hz'),set(hProfile,'Value',1);
        else,set(hProfile,'Value',2);end
        set(hWindow,'String',num2str(cfg.windowSeconds));
        set(hHop,'String',num2str(cfg.hopSeconds));
        rank=importedBundle.rank;refreshRank();
        trials=struct('path',{},'label',{},'role',{});refreshTrialTable();R=[];plotResults();
        set(hTrials,'ColumnEditable',[false false false]);
        set(hTrials,'ColumnFormat',{'char','char','char'});
        if isfield(importedBundle,'fisherScores')
            populateFrozenFisher(importedBundle.fisherScores,true);
        else
            populateFrozenFisher([],true);
        end
        msg('Loaded FROZEN Week 11 models. Import NEW Target/Confusing recordings and click Evaluate NEW.');
    end
    function runWeek12(~,~)
      try
        if isempty(importedBundle)
            error('ME3310:NoModel','Load SAVED Week 11 models first.');
        end
        cfg=importedBundle.config;
        nowCfg=currentConfig();
        if ~isequal(nowCfg.windowSeconds,cfg.windowSeconds) || ...
                ~isequal(nowCfg.hopSeconds,cfg.hopSeconds) || ...
                ~strcmp(profileName,cfg.profile)
            error('ME3310:Frozen','Do not change the frozen Week 11 feature settings for Week 12.');
        end
        [X,y,~,fs,audit]=readMeasurements(cfg);
        if isfield(importedBundle,'unitAccel') && ...
                ~strcmpi(char(importedBundle.unitAccel),char(audit.AccelUnits(1)))
            error('ME3310:UnitMismatch','Week 12 acceleration units differ from training.');
        end
        if isfield(importedBundle,'unitGyro') && ...
                ~strcmpi(char(importedBundle.unitGyro),char(audit.GyroUnits(1)))
            error('ME3310:UnitMismatch','Week 12 gyro units differ from training.');
        end
        if ~any(y==1) || ~any(y==0)
            error('ME3310:Validation','Include NEW trials for both motions.');
        end
        old=importedBundle.baselineFiles;
        if any(ismember({trials.path},old))
            error('ME3310:Leakage','A baseline MAT file was reimported! Validation requires new independent recordings.');
        end
        [res,detail]=ME3310_IMU_Core('evaluate',importedBundle.models,X,y,'Week 12 independent');
        frozenFisher=nan(1,16);frozenTable=[];
        if isfield(importedBundle,'fisherScores')
            frozenFisher=importedBundle.fisherScores;
        end
        if isfield(importedBundle,'fisherTraining')
            frozenTable=importedBundle.fisherTraining;
        end
        R=struct('models',importedBundle.models,'X',X,'y',y, ...
            'train',false(size(y)),'holdout',true(size(y)), ...
            'fisherScores',frozenFisher,'fisherTable',frozenTable, ...
            'dev',importedBundle.trainingSummary,'hold',res, ...
            'devDetail',{{}},'holdDetail',{detail},'cfg',cfg, ...
            'rank',importedBundle.rank,'fs',fs,'audit',audit,'notes',notes);
        plotResults();
        msg({sprintf('Week 12: %d NEW recordings evaluated.',numel(y)), ...
            'The Week 11 model, feature ranking, and normalization were NOT retrained.', ...
            'Check that recordings are genuinely new, not copied or reused baseline trials.'});
      catch ME
        errordlg(ME.message,'Week 12 validation failed');msg(['ERROR: ' ME.message]);
      end
    end
    function plotResults()
        cla(axTop);cla(axBottom);
        if isempty(R)
            text(axTop,.05,.5,'Import and analyze the original trials.','Units','normalized');
            text(axBottom,.05,.5,'Classifier comparison will appear here.','Units','normalized');
            return;
        end
        models=R.models;first=models(1);
        if get(hView,'Value')==2
            if any(isfinite(R.fisherScores))
                b=bar(axTop,1:16,R.fisherScores,'FaceColor',[.22 .49 .70]); %#ok<NASGU>
                xlabel(axTop,'Feature index');ylabel(axTop,'Fisher score (TRAIN only)');
                if any(R.train)
                    title(axTop,'Fisher scores: Week 11 TRAIN only');
                else
                    title(axTop,'FROZEN Week 11 TRAIN Fisher scores (not recalculated)');
                end
                grid(axTop,'on');
            else
                text(axTop,.05,.5,'Fisher scores unavailable in saved model.', ...
                    'Units','normalized');
            end
        else
            ind=first.indices;
            Z=(R.X(:,ind)-first.center)./first.scale;
            hold(axTop,'on');
            for c=[1 0]
                mask=(R.y==c & R.train);
                maskV=(R.y==c & R.holdout);
                if c==1,col=[.13 .46 .77];lab='Target';
                else,col=[.89 .47 .21];lab='Confusing';end
                if any(mask)
                    scatter(axTop,Z(mask,1),Z(mask,2),70,col,'filled', ...
                        'DisplayName',[lab ' train']);
                end
                if any(maskV)
                    if any(R.train),subset=' heldout';
                    else,subset=' NEW validation';end
                    scatter(axTop,Z(maskV,1),Z(maskV,2),100,col,'Marker','d', ...
                        'LineWidth',1.6,'DisplayName',[lab subset]);
                end
            end
            xx=xlim(axTop); yy=ylim(axTop);
            if norm(first.w)>1e-12
                if abs(first.w(2))>1e-10
                    xs=linspace(xx(1),xx(2),200);
                    ys=-(first.w(1)*xs+first.b)/first.w(2);
                    plot(axTop,xs,ys,'k--','LineWidth',1.5,'DisplayName','Linear boundary');
                elseif abs(first.w(1))>1e-10
                    xline(axTop,-first.b/first.w(1),'k--','Decision boundary');
                end
            end
            xlim(axTop,xx);ylim(axTop,yy);grid(axTop,'on');
            xlabel(axTop,['Standardized ' R.cfg.names{ind(1)}],'Interpreter','none');
            ylabel(axTop,['Standardized ' R.cfg.names{ind(2)}],'Interpreter','none');
            if any(R.train)
                title(axTop,'2D classifier (circles = train; diamonds = heldout)');
            else
                title(axTop,'Frozen Week 11 2D classifier | NEW trials (diamonds)');
            end
            legend(axTop,'Location','bestoutside','FontSize',7);
            hold(axTop,'off');
        end
        D=R.dev; H=R.hold;
        bh=bar(axBottom,D.Dimension,[D.AccuracyPct H.AccuracyPct],'grouped');
        bh(1).FaceColor=[.40 .57 .73];bh(2).FaceColor=[.89 .56 .28];
        ylim(axBottom,[0 105]);xticks(axBottom,[2 4 8 12 16]);
        xlabel(axBottom,'Number of selected features');ylabel(axBottom,'Correct trials (%)');
        if any(R.train)
            subsetTitle=sprintf('Week 11 preliminary holdout n = %d',sum(R.holdout));
            barLabels={'Week 11 train','Preliminary holdout'};
        else
            subsetTitle=sprintf('Week 12 NEW validation n = %d',sum(R.holdout));
            barLabels={'Week 11 train','Week 12 NEW'};
        end
        title(axBottom,['Trial-level accuracy | ' subsetTitle]);
        legend(axBottom,barLabels,'Location','southoutside','Orientation','horizontal');
        grid(axBottom,'on');
        lines=cell(1,5);
        for i=1:5
            lines{i}=sprintf('%2dD: train %5.1f%% | independent %5.1f%% | TP=%d FN=%d TN=%d FP=%d | Fisher(train)=%.2g', ...
                D.Dimension(i),D.AccuracyPct(i),H.AccuracyPct(i),H.TP(i),H.FN(i),H.TN(i),H.FP(i),D.TrainProjectedFisher(i));
        end
        set(hInfo,'String',[lines {'Do NOT treat tiny-sample test accuracy or in-sample Fisher as proof of reliability.'}]);
    end
    function saveResults(~,~)
      try
        if isempty(R) || isempty(modelBundle)
            error('ME3310:NoResults','Run analysis or Week 12 validation before saving.');
        end
        if any(R.train),initial='ME3310_Week11_Model.mat';stage='Week11';
        else,initial='ME3310_Week12_Validation.mat';stage='Week12';end
        % Default all exports to results/<stage>_<Target>_vs_<Confusing>.
        % Allow students to choose a different location in the Save dialog.
        toolRoot=fileparts(mfilename('fullpath'));
        tagTarget=cleanFolderName(notes.TargetMotion,'Target');
        tagConfusing=cleanFolderName(notes.ConfusingMotion,'Confusing');
        resultFolder=fullfile(toolRoot,'results', ...
            [stage '_' tagTarget '_vs_' tagConfusing]);
        if ~isfolder(resultFolder),mkdir(resultFolder);end
        suggested=fullfile(resultFolder,initial);
        [f,folder]=uiputfile('*.mat', ...
            'Export model, metadata, CSV, and plots to results folder',suggested);
        if isequal(f,0),return;end
        outputs=ME3310_export_bundle(fullfile(folder,f),modelBundle,R,...
            trials,axTop,axBottom);
        messages={['EXPORTED: ' outputs.modelMAT], ...
             ['Metadata: ' outputs.metadataTXT], ...
             'Model, feature tables, predictions and original MAT copies saved.'};
        if ~isempty(outputs.figureIssues)
            messages{end+1}=['Plot PNG not exported: ' ...
                strjoin(outputs.figureIssues,' | ')]; %#ok<AGROW>
        end
        msg(messages);
      catch ME
        errordlg(ME.message,'Export failed');msg(['ERROR: ' ME.message]);
      end
    end
    function populateFrozenFisher(scores,isFrozen)
        if isFrozen
            set(hFisherLabel,'String','Fisher (Week 11 TRAIN, frozen)');
        else
            set(hFisherLabel,'String','Fisher score (TRAIN only)');
        end
        values=[num2cell((1:16)'),repmat({'—'},16,1)];
        if ~isempty(scores) && numel(scores)==16
            for j=1:16
                if isfinite(scores(j))
                    values{j,2}=round(scores(j)*1000)/1000;
                else
                    values{j,2}='undefined';
                end
            end
        end
        set(hFisher,'Data',values);
    end
    function tag=cleanFolderName(raw,fallback)
        tag=regexprep(strtrim(char(raw)),'[^a-zA-Z0-9]+','_');
        tag=regexprep(tag,'^_+|_+$','');
        if isempty(tag),tag=fallback;end
        if numel(tag)>30,tag=tag(1:30);end
    end
    function msg(lines)
        if ischar(lines),lines={lines};end
        set(hInfo,'String',lines);
        drawnow limitrate;
    end
end
