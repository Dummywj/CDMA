function results = run_baseline(numBatches)
% Run the actual SLX model and save reproducible BER/FER evidence.
% Usage: addpath('matlab/baseline'); results = run_baseline(100);
if nargin < 1, numBatches = 100; end
validateattributes(numBatches, {'numeric'}, {'scalar','integer','positive'});
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
stopTime = sprintf('%.12g',(numBatches-1)*cfg.batchSeconds);
% Chip-rate traces are retained for one diagnostic batch only.
set_param('baseline/Log_txIQ','Commented','on');
set_param('baseline/Log_rxIQ','Commented','on');
cleanup = onCleanup(@() restore_logs(originalDirty));
ebno = [Inf -4 -2 0 2 4 6];
rows = zeros(numel(ebno),8);
for k = 1:numel(ebno)
    cfg.noiseEnabled = isfinite(ebno(k));
    cfg.EbNoDb = ebno(k);
    assignin('base','cfg',cfg);
    out = sim('baseline','StopTime',stopTime);
    tx = reshape(out.txPayload.Data.',172,[]);
    rx = reshape(out.rxPayload.Data.',172,[]);
    errors = tx ~= rx;
    decoded = reshape(out.decodedBits.Data.',192,[]);
    [~, crcFailed] = crcDetect(logical(decoded(1:184,:)),cfg.crc);
    bitErrors = nnz(errors);
    frameErrors = nnz(any(errors,1));
    rows(k,:) = [ebno(k),bitErrors,numel(errors),bitErrors/numel(errors), ...
        frameErrors,size(errors,2),frameErrors/size(errors,2),nnz(crcFailed)];
    fprintf('Eb/N0=%5g dB: BER=%.6g (%d/%d), FER=%.6g (%d/%d)\n', ...
        rows(k,1),rows(k,4),rows(k,2),rows(k,3),rows(k,7),rows(k,5),rows(k,6));
    if k == 1
        assert(bitErrors == 0 && ~any(crcFailed), 'Noiseless round trip failed.');
        expected = 1-2*out.interleavedBits.Data;
        assert(max(abs(expected(:)-out.rxSoft.Data(:))) < 1e-12, ...
            'Noiseless channel separation failed.');
    end
end
results = array2table(rows,'VariableNames', ...
    {'EbNo_dB','BitErrors','Bits','BER','FrameErrors','Frames','FER','CRCFailures'});
writetable(results,fullfile(resultDir,'ber_fer.csv'));
% A small run with all observation points permits detailed inspection.
restore_logs(originalDirty);
cfg.noiseEnabled = true; cfg.EbNoDb = 2;
assignin('base','cfg',cfg);
diagnostic = sim('baseline','StopTime','0');
repeat = sim('baseline','StopTime','0');
assert(isequal(diagnostic.rxIQ.Data,repeat.rxIQ.Data),'Noise reproducibility failed.');
n = diagnostic.rxIQ.Data - diagnostic.txIQ.Data;
expectedVariance = cfg.trafficAmplitude^2*cfg.chipRate/(172/0.02)/10^(cfg.EbNoDb/10);
measuredVariance = mean(abs(n(:)).^2);
assert(abs(measuredVariance/expectedVariance-1)<0.03,'AWGN variance check failed.');
save(fullfile(resultDir,'diagnostic.mat'),'diagnostic','cfg', ...
    'measuredVariance','expectedVariance','results');
fig = figure('Visible','off','Color','white');
semilogy(ebno(2:end),max(rows(2:end,4),0.5./rows(2:end,3)),'o-', ...
    ebno(2:end),max(rows(2:end,7),0.5./rows(2:end,6)),'s-','LineWidth',1.5);
grid on; xlabel('业务有效数据位 E_b/N_0 (dB)'); ylabel('错误率');
legend('BER（零错误点以 0.5/N 显示）','FER（零错误点以 0.5/N 显示）', ...
    'Location','southwest');
title(sprintf('单径 AWGN / 理想同步 / 每点 %d 个业务帧',4*numBatches));
exportgraphics(fig,fullfile(resultDir,'ber_fer.png'),'Resolution',160);
close(fig);
cfg.EbNoDb = 4;
assignin('base','cfg',cfg);
fprintf('Results saved to %s\n',resultDir);
end

function restore_logs(originalDirty)
if bdIsLoaded('baseline')
    set_param('baseline/Log_txIQ','Commented','off');
    set_param('baseline/Log_rxIQ','Commented','off');
    set_param('baseline','Dirty',originalDirty);
end
end
