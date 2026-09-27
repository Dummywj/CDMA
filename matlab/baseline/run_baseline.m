function results = run_baseline(numBatches, ebnoGrid)
% Run the actual SLX model and save reproducible BER-only measurements.
% Usage: addpath('matlab/baseline'); results = run_baseline();
% Optional: run_baseline(1000, -4:0.25:6).
if nargin < 1, numBatches = 1000; end
if nargin < 2, ebnoGrid = -4:0.25:6; end
validateattributes(numBatches, {'numeric'}, {'scalar','integer','positive','finite'});
validateattributes(ebnoGrid, {'numeric'}, {'vector','real','finite','nonempty'});
assert(all(diff(ebnoGrid(:))>0),'Eb/N0 points must be strictly increasing.');
root = fileparts(mfilename('fullpath'));
addpath(root);
resultDir = fullfile(fileparts(root),'results','baseline');
if ~exist(resultDir,'dir'), mkdir(resultDir); end
assignin('base','cfg',struct());
cfg = init_baseline();
modelFile = fullfile(root,'baseline.slx');
if ~isfile(modelFile), build_baseline(); end
load_system(modelFile);
originalDirty = get_param('baseline','Dirty');
logs = find_system('baseline','SearchDepth',1,'BlockType','ToWorkspace');
previous = get_param(logs,'Commented');
cleanup = onCleanup(@() restore_logs(logs,previous,originalDirty)); %#ok<NASGU>
% Keep all observation points for diagnostic checks only.
for k=1:numel(logs), set_param(logs{k},'Commented','off'); end
cfg.noiseEnabled = false;
assignin('base','cfg',cfg);
clean = sim('baseline','StopTime','0');
assert(isequal(clean.txPayload.Data,clean.rxPayload.Data),'Noiseless round trip failed.');
assert(isequal(clean.txPayload.Data,clean.packedBits.Data),'Unexpected frame overhead.');
assert(numel(clean.txPayload.Data)==768 && numel(clean.codedBits.Data)==1536);
expected = 1-2*clean.interleavedBits.Data;
assert(max(abs(expected(:)-clean.rxSoft.Data(:)))<1e-12, ...
    'Noiseless channel separation failed.');
validation.noiselessBits = numel(clean.txPayload.Data);
validation.noiselessErrors = 0;
cfg.noiseEnabled = true; cfg.EbNoDb = 2;
assignin('base','cfg',cfg);
diagnostic = sim('baseline','StopTime','0');
repeat = sim('baseline','StopTime','0');
assert(isequal(diagnostic.rxIQ.Data,repeat.rxIQ.Data),'Noise reproducibility failed.');
n = diagnostic.rxIQ.Data-diagnostic.txIQ.Data;
expectedVariance = cfg.trafficAmplitude^2*cfg.chipRate/(192/0.02)/10^(cfg.EbNoDb/10);
measuredVariance = mean(abs(n(:)).^2);
assert(abs(measuredVariance/expectedVariance-1)<0.03,'AWGN variance check failed.');
fprintf('Diagnostic checks passed; noise variance measured %.6g, expected %.6g.\n', ...
    measuredVariance,expectedVariance);
clear clean repeat n expected;
% Retain only two payload logs during the sweep to bound memory use.
for k=1:numel(logs)
    name = get_param(logs{k},'VariableName');
    if ~ismember(name,{'txPayload','rxPayload'})
        set_param(logs{k},'Commented','on');
    end
end
stopTime = sprintf('%.12g',(numBatches-1)*cfg.batchSeconds);
ebno = ebnoGrid(:).';
rows = zeros(numel(ebno),4);
elapsedSeconds = zeros(numel(ebno),1);
for k = 1:numel(ebno)
    cfg.noiseEnabled = isfinite(ebno(k));
    cfg.EbNoDb = ebno(k);
    assignin('base','cfg',cfg);
    timer = tic;
    out = sim('baseline','StopTime',stopTime);
    tx = out.txPayload.Data;
    rx = out.rxPayload.Data;
    assert(isequal(size(tx),size(rx)) && numel(tx)==numBatches*768);
    bitErrors = nnz(tx ~= rx);
    rows(k,:) = [ebno(k),bitErrors,numel(tx),bitErrors/numel(tx)];
    elapsedSeconds(k)=toc(timer);
    fprintf('[%d/%d] Eb/N0=%5g dB: BER=%.7g (%d/%d), %.1f s\n', ...
        k,numel(ebno),rows(k,1),rows(k,4),rows(k,2),rows(k,3),elapsedSeconds(k));
    results = array2table(rows(1:k,:),'VariableNames',{'EbNo_dB','BitErrors','Bits','BER'});
    writetable(results,fullfile(resultDir,'ber.csv'));
    clear out tx rx;
end
cfg.noiseEnabled=true; cfg.EbNoDb=2;
save(fullfile(resultDir,'diagnostic.mat'),'diagnostic','cfg', ...
    'measuredVariance','expectedVariance','results','elapsedSeconds','validation');
plot_baseline_ber(results,resultDir);
cfg.EbNoDb = 4;
assignin('base','cfg',cfg);
fprintf('Completed %d measured Eb/N0 points; results saved to %s\n',numel(ebnoGrid),resultDir);
end

function restore_logs(logs,previous,originalDirty)
if bdIsLoaded('baseline')
    for k=1:numel(logs), set_param(logs{k},'Commented',previous{k}); end
    set_param('baseline','Dirty',originalDirty);
end
end
