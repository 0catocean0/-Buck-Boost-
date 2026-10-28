function modelFile = build_boost28v_equiv()
% Rebuild an editable R2021b SPS boost power-stage model.
% This is NOT a TPS55340 macro-model or a validated hardware design.
rootDir = fileparts(mfilename('fullpath'));
model = 'Boost_24V_28V_equiv_v1';
modelFile = fullfile(rootDir, [model '.slx']);
load_system('sps_lib');
load_system('simulink');
if bdIsLoaded(model)
    if strcmp(get_param(model, 'Dirty'), 'on')
        error('Boost28:UnsavedModel', 'Save changes to %s before rebuilding.', model);
    end
    close_system(model, 0);
end
new_system(model);
set_param(model, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', 'p_Ts', 'StopTime', 'p_tStop', 'ReturnWorkspaceOutputs', 'on', ...
    'SignalLogging', 'off', 'SaveOutput', 'off', 'SaveTime', 'off', ...
    'Location', [60 60 1440 880]);

% R and Vf are engineering assumptions. 60 mOhm Ron uses the datasheet's
% typical 5 V test condition as an approximation, not a 24 V/hot guarantee.
p.p_Vin = 24;
p.p_L = 22e-6;
p.p_RL = 0.074;
p.p_C = 40e-6;
p.p_ESR = 0.01;
p.p_Rload = 14;
p.p_Ron = 0.06;
p.p_Rdiode = 0.001;
p.p_Vf = 0.5;
p.p_fsw = 477600;
p.p_pwmSteps = 128;
p.p_Ts = 1/(p.p_fsw*p.p_pwmSteps);
p.p_D = 21/128;
p.p_softStart = 0.005;
p.p_pwmStart = 0.003;
p.p_tStop = 0.02;
p.p_Vc0 = (p.p_Vin-p.p_Vf)/(1+(p.p_RL+p.p_Rdiode)/p.p_Rload);
p.p_IL0 = p.p_Vc0/p.p_Rload;
mw = get_param(model, 'ModelWorkspace');
fields = fieldnames(p);
for k=1:numel(fields), assignin(mw, fields{k}, p.(fields{k})); end

put('sps_lib/Sources/DC Voltage Source','Vin',[75 285 115 345], ...
    'Orientation','up','Amplitude','p_Vin');
put('sps_lib/Sensors and Measurements/Current Measurement','Iin',[155 265 190 300]);
put('sps_lib/Passives/Series RLC Branch','Inductor',[260 265 360 300], ...
    'BranchType','RL','Resistance','p_RL','Inductance','p_L', ...
    'SetiL0','on','InitialCurrent','p_IL0');
put('sps_lib/Power Electronics/Diode','Diode',[525 250 590 310], ...
    'Ron','p_Rdiode','Lon','0','Vf','p_Vf','IC','0', ...
    'UseSnubber','0','Measurements','off');
put('sps_lib/Power Electronics/Ideal Switch','Switch',[430 370 480 445], ...
    'Orientation','down','Ron','p_Ron','Lon','0','IC','0', ...
    'Rs','1e6','Cs','inf','Measurements','off');
put('sps_lib/Passives/Series RLC Branch','Output_C',[660 355 700 435], ...
    'Orientation','down','BranchType','RC','Resistance','p_ESR', ...
    'Capacitance','p_C','Setx0','on','InitialVoltage','p_Vc0');
put('sps_lib/Sensors and Measurements/Current Measurement','Iout',[800 280 835 315], ...
    'Orientation','down');
put('sps_lib/Passives/Series RLC Branch','Load_14ohm',[800 355 840 435], ...
    'Orientation','down','BranchType','R','Resistance','p_Rload');
put('sps_lib/Sensors and Measurements/Voltage Measurement','Vout',[930 310 970 365]);
put('sps_lib/Sensors and Measurements/Voltage Measurement','Vsw',[530 375 570 425]);
put('sps_lib/Utilities/Ground','Ground',[295 515 325 545]);
put('sps_lib/powergui','powergui',[70 50 185 90], ...
    'SimulationMode','Discrete','SampleTime','p_Ts');

% Sample-centred carrier avoids compare-edge roundoff changing PWM duty.
put('simulink/Sources/Repeating Sequence Stair','Carrier',[230 125 345 165], ...
    'OutValues','((0:p_pwmSteps-1)+0.5)/p_pwmSteps','tsamp','p_Ts');
put('simulink/Sources/Ramp','Duty_ramp',[60 155 110 195], ...
    'slope','p_D/p_softStart','start','p_pwmStart','InitialOutput','0');
put('simulink/Discontinuities/Saturation','Duty_limit',[150 155 195 195], ...
    'UpperLimit','p_D','LowerLimit','0');
put('simulink/Logic and Bit Operations/Relational Operator','PWM_compare', ...
    [375 145 415 190], 'Operator','>');
put('simulink/Sinks/Scope','Scope_Vout_Iout_IL',[1220 100 1275 190], ...
    'NumInputPorts','3');
scopeConfig = get_param([model '/Scope_Vout_Iout_IL'], 'ScopeConfiguration');
scopeConfig.LayoutDimensions = [3 1];
scopeConfig.TimeSpan = '0.02';
scopeConfig.DataLogging = false;
scopeConfig.DataLoggingLimitDataPoints = false;

hp = @(name) get_param([model '/' name], 'PortHandles');
vs=hp('Vin'); ii=hp('Iin'); ll=hp('Inductor'); dd=hp('Diode');
ss=hp('Switch'); cc=hp('Output_C'); io=hp('Iout'); rr=hp('Load_14ohm');
vo=hp('Vout'); vw=hp('Vsw'); gg=hp('Ground');
% SPS DC source is exceptional: RConn is +, LConn is -.
wire(vs.RConn(1),ii.LConn(1));
wire(ii.RConn(1),ll.LConn(1));
wire(ll.RConn(1),dd.LConn(1));
wire(ll.RConn(1),ss.LConn(1));
wire(ll.RConn(1),vw.LConn(1));
wire(dd.RConn(1),cc.LConn(1));
wire(dd.RConn(1),io.LConn(1));
wire(dd.RConn(1),vo.LConn(1));
wire(io.RConn(1),rr.LConn(1));
wire(vs.LConn(1),ss.RConn(1));
wire(vs.LConn(1),cc.RConn(1));
wire(vs.LConn(1),rr.RConn(1));
wire(vs.LConn(1),vo.LConn(2));
wire(vs.LConn(1),vw.LConn(2));
wire(vs.LConn(1),gg.LConn(1));
add_line(model,'Duty_ramp/1','Duty_limit/1','autorouting','on');
add_line(model,'Duty_limit/1','PWM_compare/1','autorouting','on');
add_line(model,'Carrier/1','PWM_compare/2','autorouting','on');
add_line(model,'PWM_compare/1','Switch/1','autorouting','on');
logs = {'Vout','vout_log';'Iout','iout_log';'Iin','iin_log'; ...
    'Vsw','vsw_log';'Duty_limit','duty_log';'PWM_compare','gate_log'};
tags = {'VOUT','IOUT','IL','VSW','DUTY','GATE'};
gotoPos = {[1000 335 1070 355],[860 305 925 325],[195 215 255 235], ...
    [590 420 650 440],[145 100 215 120],[440 185 505 205]};
for k=1:size(logs,1)
    put('simulink/Signal Routing/Goto',['Tag_' tags{k}],gotoPos{k}, ...
        'GotoTag',tags{k},'TagVisibility','local','ShowName','off');
    add_line(model,[logs{k,1} '/1'],['Tag_' tags{k} '/1'],'autorouting','on');
    put('simulink/Signal Routing/From',['Read_' tags{k}], ...
        [1100 255+45*(k-1) 1165 275+45*(k-1)], ...
        'GotoTag',tags{k},'ShowName','off');
    name = ['Log_' logs{k,1}];
    put('simulink/Sinks/To Workspace',name, ...
        [1210 255+45*(k-1) 1340 280+45*(k-1)], ...
        'VariableName',logs{k,2},'SaveFormat','Timeseries', ...
        'MaxDataPoints','inf','Decimation','1');
    add_line(model,['Read_' tags{k} '/1'],[name '/1'],'autorouting','on');
    if k<=3
        put('simulink/Signal Routing/From',['ScopeRead_' tags{k}], ...
            [1100 100+30*(k-1) 1165 120+30*(k-1)], ...
            'GotoTag',tags{k},'ShowName','off');
        add_line(model,['ScopeRead_' tags{k} '/1'], ...
            ['Scope_Vout_Iout_IL/' num2str(k)],'autorouting','on');
    end
end

note = Simulink.Annotation(model, sprintf([ ...
    '24 V -> 28 V BOOST | 14 ohm (~2 A)\n' ...
    'SPS switching power-stage equivalent, open-loop PWM\n' ...
    'L=22 uH; Ceff=40 uF; fs=477.6 kHz; D=21/128\n' ...
    'Default IC: input already connected, output precharged.\n' ...
    'NOT the TPS55340 controller / current-limit model.']));
note.Position = [560 40 1040 140];
set_param(model,'ZoomFactor','FitSystem');
save_system(model,modelFile);
save(fullfile(rootDir,'model_parameters.mat'),'p');
fprintf('Saved editable model: %s\n',modelFile);

    function put(lib,name,pos,varargin)
        add_block(lib,[model '/' name],'Position',pos,varargin{:});
    end
    function wire(a,b)
        add_line(model,a,b,'autorouting','on');
    end
end
