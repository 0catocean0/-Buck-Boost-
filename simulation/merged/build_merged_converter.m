function build_merged_converter()
% Merge the user's power stages with explicit equivalent feedback controls.
% Not a TPS5450/TPS55340 macro-model; run starts from energized operation.
root=fileparts(mfilename('fullpath'));
m='BuckBoost_16V_28V_merged';
load_system('sps_lib'); load_system('simulink'); load_system('nesl_utility');
load_system(fullfile(root,'Buck16V_source.slx'));
load_system(fullfile(root,'Boost28V_source.slx'));
if bdIsLoaded(m)
    if strcmp(get_param(m,'Dirty'),'on'), error('Save changes to the merged model before rebuilding.'); end
    close_system(m,0);
end
new_system(m);
set_param(m,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep','p_Ts','StopTime','p_stop','ReturnWorkspaceOutputs','on', ...
    'SignalLogging','on','SignalLoggingName','logsout', ...
    'SaveOutput','off','SaveTime','off','Location',[60 50 1500 900]);
p.p_Ts=1/298500000; % 597 ticks/Buck period, 625 ticks/Boost period.
p.p_stop=0.04;
p.p_tOpen=0.02; p.p_tClose=0.02005;
p.p_Rload=14; p.p_Rselector=0.01;
p.p_Rbleed=10000;
p.p_Kcurrent=0.04;
p.p_buckKp=0.02; p.p_buckKi=40;
p.p_boostKp=0.005; p.p_boostKi=80;
p.p_vFilterTau=20e-6;
p.p_iFilterTau=0.5e-6;
p.p_skipBand=0.03;
p.p_logDecimation=10;
mw=get_param(m,'ModelWorkspace'); fn=fieldnames(p);
for k=1:numel(fn), assignin(mw,fn{k},p.(fn{k})); end

put('Buck16V_source/DC Voltage Source','Input 24V',[75 260 105 320], ...
    'Orientation','up','Amplitude','24');
put('sps_lib/Utilities/Ground','Ground',[75 555 105 585]);
put('sps_lib/powergui','powergui',[70 45 195 85], ...
    'SimulationMode','Discrete','SampleTime','p_Ts');
make_stage('Buck16V',false,[280 135 445 245]);
make_stage('Boost28V',true,[280 365 445 475]);
put('sps_lib/Power Electronics/Ideal Switch','Select 16V',[580 150 640 195], ...
    'Ron','p_Rselector','IC','1','Rs','1e6','Cs','inf','Measurements','off');
put('sps_lib/Power Electronics/Ideal Switch','Select 28V',[580 380 640 425], ...
    'Ron','p_Rselector','IC','0','Rs','1e6','Cs','inf','Measurements','off');
put('simulink/Sources/Step','16V disconnect at 20ms',[465 85 515 115], ...
    'Time','p_tOpen','Before','1','After','0','SampleTime','0');
put('simulink/Sources/Step','28V connect at 20_05ms',[465 315 515 345], ...
    'Time','p_tClose','Before','0','After','1','SampleTime','0');
put('sps_lib/Sensors and Measurements/Current Measurement','Load current',[740 270 780 300]);
put('sps_lib/Passives/Series RLC Branch','Common load 14ohm',[825 370 865 450], ...
    'Orientation','down','BranchType','R','Resistance','p_Rload');
put('sps_lib/Sensors and Measurements/Voltage Measurement','Common output',[915 305 955 355]);
put('simulink/Sinks/Scope','Scope',[1110 155 1190 300],'NumInputPorts','4');
cfg=get_param([m '/Scope'],'ScopeConfiguration');
cfg.LayoutDimensions=[4 1]; cfg.TimeSpan='0.04'; cfg.DataLoggingLimitDataPoints=false;
v=ports('Input 24V'); g=ports('Ground'); b=ports('Buck16V'); u=ports('Boost28V');
s1=ports('Select 16V'); s2=ports('Select 28V'); ii=ports('Load current');
r=ports('Common load 14ohm'); vo=ports('Common output');
wire(v.RConn,b.LConn(1)); wire(v.RConn,u.LConn(1));
wire(v.LConn,b.LConn(2)); wire(v.LConn,u.LConn(2)); wire(v.LConn,g.LConn);
wire(b.RConn,s1.LConn); wire(u.RConn,s2.LConn);
wire(s1.RConn,ii.LConn); wire(s2.RConn,ii.LConn);
wire(ii.RConn,r.LConn); wire(ii.RConn,vo.LConn(1));
wire(v.LConn,r.RConn); wire(r.RConn,vo.LConn(2));
sig('16V disconnect at 20ms/1','Select 16V/1');
sig('28V connect at 20_05ms/1','Select 28V/1');
sig('Common output/1','Scope/1'); sig('Load current/1','Scope/2');
sig('Buck16V/1','Scope/3'); sig('Boost28V/1','Scope/4');
logport(vo.Outport,'Vload'); logport(ii.Outport,'Iload');
logport(b.Outport,'Vbuck'); logport(u.Outport,'Vboost');
note=Simulink.Annotation(m,sprintf(['24 V stays ON | 16 V -> 28 V output selection\n' ...
    '20 ms: open 16 V; 20.05 ms: close 28 V\n' ...
    'Scope: Vload, Iload, Vbuck, Vboost\n' ...
    'Equivalent feedback; energized initial state, not cold start.']));
note.Position=[660 35 1170 120];
set_param(m,'ZoomFactor','FitSystem');
save_system(m,fullfile(root,[m '.slx']));
save(fullfile(root,'merged_parameters.mat'),'p');
fprintf('Saved merged model: %s\n',fullfile(root,[m '.slx']));

    function make_stage(stage,isBoost,pos)
        sys=[m '/' stage];
        add_block('built-in/Subsystem',sys,'Position',pos);
        port('VIN',1,'Left',[30 310 60 330]);
        port('GND',2,'Left',[30 555 60 575]);
        port('OUT',3,'Right',[1040 345 1070 365]);
        if isBoost
            src='Boost28V_source'; L='L 22uH'; C='Co 40uF'; S='Switch';
            IL='IL'; VV='Vout'; R='Load 14ohm'; Vref=28; nTicks=625;
            kp='p_boostKp'; ki='p_boostKi'; dutyff='1-24/(28+0.5)';
            ff='(p_Kcurrent+0.074/(28+0.5))*(28+0.5)/24';
            i0='0';
        else
            src='Buck16V_source'; L='Series RLC Branch'; C='Series RLC Branch1';
            S='Ideal Switch'; IL='Current Measurement'; VV='Voltage Measurement';
            R='Series RLC Branch2'; Vref=16; nTicks=597;
            kp='p_buckKp'; ki='p_buckKi'; dutyff='(16+0.5)/(24+0.5)';
            ff='p_Kcurrent+0.074/24';
            i0='16/(p_Rload+p_Rselector)+16/p_Rbleed';
        end
        if isBoost
            cp(L,'L',[170 310 265 340]);
            cp(IL,'IL',[300 313 335 337]);
            cp('Diode','D',[500 300 560 350]);
            cp(S,'Q',[405 420 455 490]); set_param([sys '/Q'],'Orientation','down');
        else
            cp(S,'Q',[150 300 210 350]); set_param([sys '/Q'],'Orientation','right');
            cp('Diode','D',[265 420 315 485]); set_param([sys '/D'],'Orientation','up');
            cp(L,'L',[345 310 440 340]); cp(IL,'IL',[475 313 510 337]);
        end
        cp(C,'Cout',[680 350 780 380]); set_param([sys '/Cout'],'Orientation','right');
        cp(R,'Bleeder 10k',[680 440 780 470]);
        set_param([sys '/Bleeder 10k'],'Orientation','right','BranchType','R', ...
            'Resistance','p_Rbleed');
        cp(VV,'Voltage',[920 380 960 430]);
        add_block('sps_lib/Sensors and Measurements/Current Measurement', ...
            [sys '/Iout'],'Position',[910 313 945 337]);
        set_param([sys '/L'],'SetiL0','on','InitialCurrent',i0);
        set_param([sys '/Cout'],'Setx0','on','InitialVoltage',num2str(Vref));
        set_param([sys '/Q'],'Measurements','off','Rs','1e6','Cs','inf','IC','0');
        set_param([sys '/D'],'Measurements','off','UseSnubber','0');
        hp=@(name)get_param([sys '/' name],'PortHandles');
        pv=hp('VIN'); pg=hp('GND'); po=hp('OUT'); ll=hp('L'); il=hp('IL');
        dd=hp('D'); qq=hp('Q'); cc=hp('Cout'); rb=hp('Bleeder 10k');
        vm=hp('Voltage'); io=hp('Iout');
        vin=physical(pv); ground=physical(pg); output=physical(po);
        if isBoost
            swire(vin,ll.LConn); swire(ll.RConn,il.LConn);
            swire(il.RConn,dd.LConn); swire(il.RConn,qq.LConn);
            swire(qq.RConn,ground); node=dd.RConn;
        else
            swire(vin,qq.LConn); swire(qq.RConn,ll.LConn);
            swire(qq.RConn,dd.RConn); swire(dd.LConn,ground);
            swire(ll.RConn,il.LConn); node=il.RConn;
        end
        swire(node,cc.LConn); swire(node,rb.LConn); swire(node,vm.LConn(1));
        swire(node,io.LConn); swire(io.RConn,output);
        swire(ground,cc.RConn); swire(ground,rb.RConn); swire(ground,vm.LConn(2));

        % Sampled voltage PI plus load feedforward and current damping.
        tc=sprintf('p_Ts*%d',nTicks);
        add('simulink/Sources/Constant','Vref',[70 55 120 85],'Value',num2str(Vref));
        add('simulink/Discrete/Zero-Order Hold','V sample',[95 140 150 170],'SampleTime',tc);
        filter('V average',[195 140 275 170],'p_vFilterTau',num2str(Vref));
        add('simulink/Math Operations/Sum','Error',[320 60 345 95],'Inputs','+-');
        add('simulink/Discrete/Discrete PID Controller','PI equivalent',[385 55 470 100], ...
            'Controller','PI','P',kp,'I',ki,'SampleTime',tc, ...
            'InitialConditionForIntegrator','0','LimitOutput','on', ...
            'UpperSaturationLimit','0.3','LowerSaturationLimit','-0.2', ...
            'AntiWindupMode','clamping','ExternalReset','level');
        add('simulink/Discrete/Zero-Order Hold','Io sample',[95 220 150 250],'SampleTime',tc);
        add('simulink/Math Operations/Gain','Load feedforward',[195 220 275 250],'Gain',ff);
        add('simulink/Sources/Constant','Duty base',[390 165 470 195],'Value',dutyff);
        add('simulink/Discrete/Zero-Order Hold','IL sample',[95 600 150 630],'SampleTime',tc);
        filter('IL average',[195 600 275 630],'p_iFilterTau',i0);
        add('simulink/Math Operations/Gain','Current damping',[325 600 400 630],'Gain','p_Kcurrent');
        add('simulink/Math Operations/Sum','Duty sum',[530 65 555 125],'Inputs','+++-');
        add('simulink/Discontinuities/Saturation','Duty 0 to 085',[590 70 650 110], ...
            'LowerLimit','0','UpperLimit','0.85');
        add('simulink/Sources/Repeating Sequence Stair','PWM carrier',[585 165 650 205], ...
            'OutValues',sprintf('((0:%d)+0.5)/%d',nTicks-1,nTicks),'tsamp','p_Ts');
        add('simulink/Logic and Bit Operations/Relational Operator','PWM',[700 75 735 115],'Operator','>');
        add('simulink/Sources/Constant','Skip threshold',[385 220 470 250], ...
            'Value',sprintf('%g+p_skipBand',Vref));
        add('simulink/Logic and Bit Operations/Relational Operator','Allow pulse',[700 220 735 260],'Operator','<');
        add('simulink/Sources/Constant','Light load boundary',[385 270 470 300],'Value','0.1');
        add('simulink/Logic and Bit Operations/Relational Operator','Loaded',[700 275 735 310],'Operator','>');
        add('simulink/Logic and Bit Operations/Logical Operator','Reset at light load',[770 275 810 310], ...
            'Operator','NOT');
        add('simulink/Logic and Bit Operations/Logical Operator','Voltage guard',[770 215 810 255], ...
            'Operator','OR','Inputs','2');
        add('simulink/Logic and Bit Operations/Logical Operator','Gate',[805 90 850 135], ...
            'Operator','AND','Inputs','2');
        add('simulink/Discrete/Unit Delay','Gate delay',[875 90 925 135], ...
            'SampleTime','p_Ts','InitialCondition','0');
        add('simulink/Ports & Subsystems/Out1','V feedback',[1030 225 1060 245],'Port','1');
        sl('Voltage/1','V sample/1'); sl('V sample/1','V average/1');
        sl('Vref/1','Error/1'); sl('V average/1','Error/2'); sl('Error/1','PI equivalent/1');
        sl('Iout/1','Io sample/1'); sl('Io sample/1','Load feedforward/1');
        sl('IL/1','IL sample/1'); sl('IL sample/1','IL average/1');
        sl('IL average/1','Current damping/1');
        sl('PI equivalent/1','Duty sum/1'); sl('Duty base/1','Duty sum/2');
        sl('Load feedforward/1','Duty sum/3'); sl('Current damping/1','Duty sum/4');
        sl('Duty sum/1','Duty 0 to 085/1'); sl('Duty 0 to 085/1','PWM/1');
        sl('PWM carrier/1','PWM/2');
        sl('V average/1','Allow pulse/1'); sl('Skip threshold/1','Allow pulse/2');
        sl('Io sample/1','Loaded/1'); sl('Light load boundary/1','Loaded/2');
        sl('Loaded/1','Reset at light load/1'); sl('Reset at light load/1','PI equivalent/2');
        sl('Allow pulse/1','Voltage guard/1'); sl('Loaded/1','Voltage guard/2');
        sl('PWM/1','Gate/1'); sl('Voltage guard/1','Gate/2');
        sl('Gate/1','Gate delay/1'); sl('Gate delay/1','Q/1');
        sl('Voltage/1','V feedback/1');
        logport(il.Outport,[lower(stage) '_IL']);
        logport(io.Outport,[lower(stage) '_Iout']);
        controls={'Vref','V sample','V average','Error','PI equivalent', ...
            'Io sample','Load feedforward','Duty base','IL sample','IL average', ...
            'Current damping','Duty sum','Duty 0 to 085','PWM carrier','PWM', ...
            'Skip threshold','Allow pulse','Light load boundary','Loaded', ...
            'Reset at light load','Voltage guard','Gate','Gate delay'};
        handles=zeros(1,numel(controls));
        for jc=1:numel(controls), handles(jc)=get_param([sys '/' controls{jc}],'Handle'); end
        Simulink.BlockDiagram.createSubsystem(handles,'Name','Equivalent feedback');
        set_param([sys '/Equivalent feedback'],'Position',[160 70 350 180], ...
            'ContentPreviewEnabled','off');
        set_param(sys,'ShowPortLabels','FromPortIcon','ZoomFactor','FitSystem', ...
            'ContentPreviewEnabled','off');

        function cp(sourceName,name,position)
            add_block([src '/' sourceName],[sys '/' name],'Position',position);
        end
        function add(lib,name,position,varargin)
            add_block(lib,[sys '/' name],'Position',position,varargin{:});
        end
        function port(name,number,side,position)
            add('nesl_utility/Connection Port',name,position,'Port',num2str(number),'Side',side);
        end
        function filter(name,position,tau,initial)
            aa=sprintf('exp(-(%s)/(%s))',tc,tau);
            add('simulink/Discrete/Discrete Transfer Fcn',name,position, ...
                'Numerator',['1-' aa],'Denominator',['[1 -' aa ']'], ...
                'InitialStates',sprintf('(%s)/(1-(%s))',initial,aa),'SampleTime',tc);
        end
        function swire(x,y), add_line(sys,x,y,'autorouting','on'); end
        function sl(x,y), add_line(sys,x,y,'autorouting','on'); end
    end
    function h=physical(portspec)
        h=[portspec.LConn portspec.RConn]; h=h(1);
    end
    function put(lib,name,pos,varargin)
        add_block(lib,[m '/' name],'Position',pos,varargin{:});
    end
    function h=ports(name), h=get_param([m '/' name],'PortHandles'); end
    function wire(x,y), add_line(m,x,y,'autorouting','on'); end
    function sig(x,y), add_line(m,x,y,'autorouting','on'); end
    function logport(h,name)
        set_param(h,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',name, ...
            'DataLoggingDecimateData','on','DataLoggingDecimation','p_logDecimation');
    end
end
