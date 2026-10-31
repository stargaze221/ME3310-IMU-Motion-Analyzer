function ME3310_generate_demo()
% ME3310_GENERATE_DEMO -- SYNTHETIC FILES FOR SOFTWARE CHECKS ONLY.
% NOT observations and NOT valid course-project experimental evidence.
% Generates 3 Target and 3 Confusing recordings in a separate folder.
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'DEMO_SYNTHETIC_NOT_EXPERIMENTAL_DATA');
if ~exist(out,'dir'),mkdir(out);end
rng(3310,'twister');
fs=20;
t=(0:1/fs:11.95)';
for cls=0:1
  for trial=1:3
    phase=2*pi*rand();
    f0=1.1+0.13*randn();
    a0=0.11+0.08*cls;
    accel=[a0*sin(2*pi*f0*t+phase)+0.025*randn(size(t)), ...
           a0*cos(2*pi*f0*t+phase)+0.025*randn(size(t)), ...
           1+0.04*sin(2*pi*2*f0*t)+0.015*randn(size(t))];
    gyro=[(8+15*cls)*sin(2*pi*f0*t+phase)+2*randn(size(t)), ...
          5*cos(2*pi*.5*f0*t)+2*randn(size(t)), ...
          (5+6*cls)*cos(2*pi*f0*t)+1.5*randn(size(t))];
    if cls==1,label='Target';else,label='Confusing';end
    meta=struct('ID',sprintf('SYNTH_%s_%02d',label,trial), ...
          'EventLabel',label,'Units',struct('accel','g','gyro','deg/s'));
    save(fullfile(out,sprintf('SYNTH_%s_%02d.mat',label,trial)), ...
         't','accel','gyro','meta');
  end
end
fprintf('Demo files generated at: %s\n',out);
fprintf('These files are SYNTHETIC, for tool smoke testing only.\n');
end
