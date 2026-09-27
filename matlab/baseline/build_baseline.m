function modelFile = build_baseline()
%BUILD_BASELINE Create the flat, frame-batch CDMA teaching model.
% Each interpreted block calls baseline_step(stage, u). All outputs are
% fixed-size double vectors; the IQ spreading and noise outputs are complex.
% Run this builder separately from simulation, then use sim('baseline').

matlabDir = fileparts(mfilename('fullpath'));
model = 'baseline';
modelFile = fullfile(matlabDir, [model '.slx']);
addpath(matlabDir);

if bdIsLoaded(model)
    if strcmp(get_param(model, 'Dirty'), 'on')
        error('CDMA:UnsavedModel', ...
            'Save or close the modified baseline model before rebuilding.');
    end
    close_system(model, 0);
end
load_system('simulink');
new_system(model);

% Configure 10 batches at t = 0, 0.08, ..., 0.72 seconds.
set_param(model, ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '0.08', ...
    'StartTime', '0', ...
    'StopTime', '0.72', ...
    'SimulationMode', 'normal', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SaveTime', 'on', ...
    'TimeSaveName', 'tout', ...
    'SaveOutput', 'off', ...
    'SignalLogging', 'off', ...
    'LimitDataPoints', 'off', ...
    'ScreenColor', 'white');
set_param(model, 'InitFcn', ...
    ['addpath(fileparts(get_param(bdroot,''FileName''))); ' ...
     'init_baseline;']);

% Keep the diagram readable by arranging source, channel, and receiver rows.
add_block('simulink/Sources/Digital Clock', [model '/Clock'], ...
    'SampleTime', '0.08', 'Position', [35 225 95 255]);
add_block('simulink/Signal Routing/Goto', [model '/BatchTimeTag'], ...
    'GotoTag', 'BatchTime', 'TagVisibility', 'local', ...
    'Position', [35 275 115 300]);
add_line(model, 'Clock/1', 'BatchTimeTag/1', 'autorouting', 'on');

stage('TrafficSource', 768, 'real', [170 130 295 175]);
stage('FramePack', 768, 'real', [355 130 480 175]);
stage('ConvEncode', 1536, 'real', [540 130 665 175]);
stage('Interleave', 1536, 'real', [725 130 850 175]);
stage('TrafficWalsh', 98304, 'real', [910 130 1040 175]);
chain({'Clock', 'TrafficSource', 'FramePack', 'ConvEncode', ...
    'Interleave', 'TrafficWalsh'});

stage('SyncSource', 96, 'real', [170 340 295 385]);
stage('SyncEncode', 192, 'real', [405 340 530 385]);
stage('SyncRepeatInterleave', 384, 'real', [630 340 800 385]);
stage('SyncWalsh', 98304, 'real', [910 340 1040 385]);
chain({'Clock', 'SyncSource', 'SyncEncode', ...
    'SyncRepeatInterleave', 'SyncWalsh'});

add_block('simulink/Sources/Constant', [model '/PilotAmplitude'], ...
    'Value', 'cfg.pilotAmplitude', 'SampleTime', '0.08', ...
    'OutDataTypeStr', 'double', 'Position', [665 465 730 500]);
stage('PilotWalsh', 98304, 'real', [910 460 1040 505]);
add_line(model, 'PilotAmplitude/1', 'PilotWalsh/1', 'autorouting', 'on');
add_block('simulink/Math Operations/Sum', [model '/ChannelSum'], ...
    'Inputs', '+++', 'IconShape', 'rectangular', ...
    'Position', [1120 335 1155 390]);
add_line(model, 'TrafficWalsh/1', 'ChannelSum/1', 'autorouting', 'on');
add_line(model, 'SyncWalsh/1', 'ChannelSum/2', 'autorouting', 'on');
add_line(model, 'PilotWalsh/1', 'ChannelSum/3', 'autorouting', 'on');

% Read the channel row from right to left to avoid a very wide canvas.
stage('IQSpread', 98304, 'complex', [1060 595 1190 640], 'left');
add_line(model, 'ChannelSum/1', 'IQSpread/1', 'autorouting', 'on');
add_block('simulink/Signal Routing/Mux', [model '/AWGNInput'], ...
    'Inputs', '[98304 1]', 'Orientation', 'left', ...
    'Position', [945 590 955 645]);
add_block('simulink/Signal Routing/From', [model '/NoiseBatchTime'], ...
    'GotoTag', 'BatchTime', 'Orientation', 'left', ...
    'Position', [1000 700 1090 725]);
add_block('simulink/Math Operations/Real-Imag to Complex', [model '/ComplexTime'], ...
    'Input','Real','Orientation','left','Position',[925 700 955 730]);
add_line(model, 'IQSpread/1', 'AWGNInput/1', 'autorouting', 'on');
add_line(model, 'NoiseBatchTime/1', 'ComplexTime/1', 'autorouting', 'on');
add_line(model, 'ComplexTime/1', 'AWGNInput/2', 'autorouting', 'on');
stage('AWGN', 98304, 'complex', [745 595 875 640], 'left');
stage('IQDespread', 98304, 'real', [525 595 655 640], 'left');
stage('TrafficDespread', 1536, 'real', [305 595 445 640], 'left');
chain({'AWGNInput', 'AWGN', 'IQDespread', 'TrafficDespread'});

stage('Deinterleave', 1536, 'real', [305 835 445 880]);
stage('Viterbi', 768, 'real', [565 835 695 880]);
stage('PayloadExtract', 768, 'real', [815 835 960 880]);
chain({'TrafficDespread', 'Deinterleave', 'Viterbi', 'PayloadExtract'});
add_block('simulink/Signal Routing/Goto',[model '/TxBitsTag'], ...
    'GotoTag','TxBits','TagVisibility','local','Position',[270 270 345 295]);
add_line(model,'TrafficSource/1','TxBitsTag/1','autorouting','on');
add_block('simulink/Signal Routing/From',[model '/TxBitsForCompare'], ...
    'GotoTag','TxBits','Position',[1010 775 1110 800]);
add_block('simulink/Signal Routing/Mux',[model '/CompareBits'], ...
    'Inputs','[768 768]','Position',[1040 835 1050 895]);
add_line(model,'TxBitsForCompare/1','CompareBits/1','autorouting','on');
add_line(model,'PayloadExtract/1','CompareBits/2','autorouting','on');
stage('BatchErrors',1,'real',[1110 830 1220 875]);
add_line(model,'CompareBits/1','BatchErrors/1');
add_block('simulink/Sinks/Display',[model '/BER'], ...
    'Position',[1100 930 1235 995]);
add_line(model,'BatchErrors/1','BER/1','autorouting','on');

% Record only the required observation points to keep chip logging bounded.
record('TrafficSource', 'txPayload', [180 215 290 245]);
record('FramePack', 'packedBits', [360 215 475 245]);
record('ConvEncode', 'codedBits', [545 215 660 245]);
record('Interleave', 'interleavedBits', [720 215 855 245]);
record('IQSpread', 'txIQ', [1090 665 1190 695]);
record('AWGN', 'rxIQ', [760 690 860 720]);
record('TrafficDespread', 'rxSoft', [315 690 435 720]);
record('Viterbi', 'decodedBits', [570 930 690 960]);
record('PayloadExtract', 'rxPayload', [830 930 945 960]);

note(sprintf(['CDMA 基线教学模型：顶层逐级观察\n' ...
    '每批 80 ms；默认 10 批；业务帧 20 ms，同步帧 26 2/3 ms']), ...
    [35 25], 15);
note('业务发送：4 × 192 位业务比特 → 帧组织（透传）→ 卷积编码 → 交织 → Walsh 扩频', ...
    [170 90], 11);
note('同步发送：96 → 192 → 384 → 98 304；导频幅度 0.5', [170 310], 11);
note('信道与接收前端（由右向左）：I/Q 扩频 → 加噪 → I/Q 解扩 → 业务解扩', ...
    [305 550], 11);
note('噪声输入末项为批次时间；其余 98 304 项为复数 I/Q 样本', [700 765], 10);
note('业务接收（由左向右）：解交织 → 截断模式 Viterbi 译码 → 192 位业务输出', [305 790], 11);
note(sprintf(['观测输出保存为 timeseries；BER 在仿真后比较 txPayload 与 rxPayload\n' ...
    '每帧 192 个业务比特；显示器为当前批次 BER']), ...
    [35 1010], 11);

set_param(model, 'ZoomFactor', 'FitSystem');
save_system(model, modelFile);
fprintf('Created %s\n', modelFile);

    function stage(name, width, complexity, position, orientation)
        if nargin < 5
            orientation = 'right';
        end
        block = [model '/' name];
        add_block('built-in/MATLABFcn', block, ...
            'MATLABFcn', sprintf('baseline_step(''%s'',u)', name), ...
            'OutputDimensions', num2str(width), ...
            'OutputSignalType', complexity, ...
            'Output1D', 'on', ...
            'SampleTime', '-1', ...
            'Position', position, ...
            'Orientation', orientation, ...
            'FontSize', '10', ...
            'BackgroundColor', 'white');
    end

    function chain(names)
        for k = 1:numel(names)-1
            add_line(model, [names{k} '/1'], [names{k+1} '/1'], ...
                'autorouting', 'on');
        end
    end

    function record(source, variable, position)
        blockName = ['Log_' variable];
        add_block('simulink/Sinks/To Workspace', [model '/' blockName], ...
            'VariableName', variable, 'SaveFormat', 'Timeseries', ...
            'MaxDataPoints', 'inf', 'Decimation', '1', ...
            'SampleTime', '-1', 'Position', position, ...
            'ShowName', 'on', 'FontSize', '9');
        add_line(model, [source '/1'], [blockName '/1'], 'autorouting', 'on');
    end

    function note(text, position, fontSize)
        annotation = Simulink.Annotation(model, text);
        annotation.Position = position;
        annotation.FontSize = fontSize;
    end
end
