function plot_baseline_ber(results,resultDir)
% Plot measured BER; do not fabricate positive values for zero-error trials.
if nargin<2
    root=fileparts(mfilename('fullpath'));
    resultDir=fullfile(fileparts(root),'results','baseline');
end
if nargin<1, results=readtable(fullfile(resultDir,'ber.csv')); end
data=results(isfinite(results.EbNo_dB),:);
fig=figure('Visible','off','Color','white','Position',[100 100 1000 650]);
cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
measured=data.BER; measured(measured==0)=NaN;
semilogy(data.EbNo_dB,measured,'o-','LineWidth',1.7, ...
    'MarkerSize',4,'Color',[0.05 0.35 0.7],'MarkerFaceColor',[0.05 0.35 0.7]);
grid on; box on;
xlabel('业务比特 E_b/N_0（dB）'); ylabel('比特误码率 BER');
title('单径 AWGN、理想同步：业务比特误码率');
subtitle(sprintf('每帧 192 bit；每点 %s bit；%d 个实测信噪比点', ...
    num2str(data.Bits(1),'%d'),height(data)));
set(gca,'FontSize',12);
if height(data)>1, xlim([min(data.EbNo_dB),max(data.EbNo_dB)]); end
zero=data.BitErrors==0;
if any(zero)
    text(0.03,0.07,sprintf('未观察到误码的点：%s dB\n零错误点未连接到曲线；原始计数见 CSV', ...
        strjoin(compose('%g',data.EbNo_dB(zero)),', ')), ...
        'Units','normalized','FontSize',10,'BackgroundColor','white');
end
exportgraphics(fig,fullfile(resultDir,'ber.png'),'Resolution',180);
end
