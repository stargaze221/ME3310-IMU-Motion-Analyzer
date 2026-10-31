function ME3310_organize_existing()
% ME3310_ORGANIZE_EXISTING  One-time, safe cleanup of older GUI exports.
%
% Run this from the IMU Analyzer repository (or with its folder on the path):
%   ME3310_organize_existing
%
% Only moves known program-generated files found in the repository ROOT:
%   ME3310_Week11_Model*
%   ME3310_Week12_Validation*
%   DEMO_SYNTHETIC_NOT_EXPERIMENTAL_DATA/
%
% Does not move original PocketLab driver files, rewrite the contents of
% archived MAT records, overwrite existing results, or remove source data.
% If old metadata TXT contains absolute export paths, those paths are
% historical records and are NOT rewritten by this utility.

root=fileparts(mfilename('fullpath'));
results=fullfile(root,'results');
if ~isfolder(results),mkdir(results);end

groups={...
    'ME3310_Week11_Model*','Legacy_Week11_Model';...
    'ME3310_Week12_Validation*','Legacy_Week12_Validation'};
moved=0;
skipped=0;

for g=1:size(groups,1)
    listing=dir(fullfile(root,groups{g,1}));
    if isempty(listing),continue;end
    destination=fullfile(results,groups{g,2});
    if ~isfolder(destination),mkdir(destination);end
    for k=1:numel(listing)
        name=listing(k).name;
        if strcmp(name,'.') || strcmp(name,'..'),continue;end
        old=fullfile(root,name);
        new=fullfile(destination,name);
        if isfile(new) || isfolder(new)
            fprintf('SKIP (already exists): %s\n',new);
            skipped=skipped+1;
            continue;
        end
        [ok,message]=movefile(old,new);
        if ok
            fprintf('Moved: %s -> %s\n',name,destination);
            moved=moved+1;
        else
            fprintf('SKIP (move unsuccessful): %s | %s\n',old,message);
            skipped=skipped+1;
        end
    end
end

demoName='DEMO_SYNTHETIC_NOT_EXPERIMENTAL_DATA';
oldDemo=fullfile(root,demoName);
newDemo=fullfile(results,demoName);
if isfolder(oldDemo)
    if isfolder(newDemo)
        fprintf('SKIP old synthetic demo: new demo folder already exists.\n');
        skipped=skipped+1;
    else
        [ok,message]=movefile(oldDemo,newDemo);
        if ok
            fprintf('Moved synthetic demo folder to results/.\n');
            moved=moved+1;
        else
            fprintf('SKIP synthetic demo: %s\n',message);
            skipped=skipped+1;
        end
    end
end

fprintf('\nCleanup complete: %d moved, %d skipped.\n',moved,skipped);
fprintf('All future GUI exports default under: %s\n',results);
fprintf('Original PocketLab recordings were NOT modified.\n');
end
