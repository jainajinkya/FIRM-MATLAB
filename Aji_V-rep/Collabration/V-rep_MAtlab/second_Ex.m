clear classes;clear variables;close all;clc;
seed =502; rand('state',seed);randn('state',seed); %#ok<RAND>
addpath(genpath('General_functions')); % In this line we add everything inside the "General_functions" to the current paths of the matlab.
startup
load myfilebrkpnts;%dbstop(s)

% Parameters
user_data = user_data_class; % The object user_data will never be used. This line only cause the "Constant" properties of the "user_data_class" class to be initialized.


% aa = state.sample_a_valid_state;
% bb = state.sample_a_valid_state;
clc
% dbstop in error
aa = state;
bb = state;

aa.val = [-2;0;-pi/6];
bb.val = [1;2;pi/6];

mm = Unicycle_robot;
% w = [0;0;0;0;0];

action = mm.generate_VALID_open_loop_point2point_traj(aa,bb);

disp('Program started');
vrep = remApi('remoteApi','extApi.h');
clientID = vrep.simxStart('127.0.0.1',19999,true,true,5000,5)

if (clientID>-1)
    disp('Connected to remote API server');
    % 		[res,objs]=vrep.simxGetObjects(clientID,vrep.sim_handle_all,vrep.simx_opmode_oneshot_wait);
    % 		if (res==vrep.simx_error_noerror)
    % 			fprintf('Number of objects in the scene: %d\n',length(objs));
    % 		else
    % 			fprintf('Remote API function call returned with error code: %d\n',res);
    % 		end
    
%     [res] = vrep.simxTransferFile(clientID,'/home/ajinkya/Dropbox/FIRM_toolbox_ver_current/cube1.obj','cube1.obj',20,vrep.simx_opmode_oneshot_wait);
    %         pause(1);
    
    % CREATING A DUMMY OBJECT
    %[res, dummy]= simxCreateDummy(clientID,2,[],simx_opmode_oneshot_wait);
    
    
    
    %% Put this in Constructor of the simulator class
    % Load the scene
    sce = 'C:\Users\Ajinkya\Desktop\Summers13\V-rep_matlab\Scenes\test.ttt';
    [response] = vrep.simxLoadScene(clientID,sce,0,vrep.simx_opmode_oneshot_wait);
    pause(1);
    fprintf('Load command sent...\n');
    
    pause(3)
    %         for i=1:numberOfObjects
    %         [res, cube] = vrep.simxGetObjectHandle(clientID,num2str(i),vrep.simx_opmode_oneshot_wait);
    
%     [res, cube] = vrep.simxGetObjectHandle(clientID,'Shape',vrep.simx_opmode_oneshot_wait);
    [res, bot] = vrep.simxGetObjectHandle(clientID,'dr20',vrep.simx_opmode_oneshot_wait);
    [res, left_joint] = vrep.simxGetObjectHandle(clientID,'dr20_leftWheelJoint_',vrep.simx_opmode_oneshot_wait);
    [res, right_joint] = vrep.simxGetObjectHandle(clientID,'dr20_rightWheelJoint_',vrep.simx_opmode_oneshot_wait);
    [res, robot_joints] = vrep.simxGetObjects(clientID, vrep.sim_object_joint_type,vrep.simx_opmode_oneshot_wait);

    
    % Uncomment this for defining obstacle parameteres in V-rep
%     [res1] = vrep.simxSetObjectIntParameter(clientID, cube, 3003, ~0,vrep.simx_opmode_oneshot_wait);
%     [res2] = vrep.simxSetObjectIntParameter(clientID, cube, 3004, ~0,vrep.simx_opmode_oneshot_wait);
    
       
    % Loading the robot model
%           [res, bot] = vrep.simxLoadModel(clientID,'/home/ajinkya/summer13/V-REP_PRO_EDU_V3_0_3_Linux/models/robots/mobile/dr20.ttm',0,vrep.simx_opmode_oneshot_wait);
%           [res, prop] = vrep.simxGetObjectChild(clientID, bot, 11,vrep.simx_opmode_oneshot_wait); 
%     
    
    
    %% Defining it in the class
    
    %  15Starting simulation
    [res] = vrep.simxStartSimulation(clientID,vrep.simx_opmode_oneshot);
    
    
    % Initializing scene saving
    %        [res,replyData]=vrep.simxQuery(clientID,'request','save','reply',5000)
    %        if (res==vrep.simx_error_noerror)
    %            fprintf('scene saved\n');
    %            sce = replyData;
    %            fprintf('scene saved at location: %s\n', sce);
    %        end
    
    %% Defining position of the Bot in V-rep
%          [res] = vrep.simxSetObjectPosition(clientID,bot,-1,[0,0,0.1517],vrep.simx_opmode_oneshot_wait);
%          [res1] = vrep.simxSetObjectOrientation(clientID,bot,-1,[0,0,0],vrep.simx_opmode_oneshot_wait);

     % Enabling the joints dynamically
        [res1] = vrep.simxSetObjectIntParameter(clientID, left_joint, 2000, ~0,vrep.simx_opmode_oneshot_wait);
        [res2] = vrep.simxSetObjectIntParameter(clientID, right_joint, 2000, ~0,vrep.simx_opmode_oneshot_wait);
        
    
    for i= 1:1:(length(action.u))
        %
        %              [res] = vrep.simxSetObjectPosition(clientID,bot,-1,[action.x(1,i),action.x(2,i),0.15],vrep.simx_opmode_oneshot_wait);
        %             [res1] = vrep.simxSetObjectOrientation(clientID,bot,-1,[0,0,action.x(3,i)],vrep.simx_opmode_oneshot_wait);
        %             pause(2);

        
        % giving motor velocity
            [res] = vrep.simxSetJointTargetVelocity(clientID,left_joint, 2*(action.u(1,i)+((action.u(2,i)*0.254)/2)), vrep.simx_opmode_oneshot_wait);
            [res] = vrep.simxSetJointTargetVelocity(clientID,right_joint, 2*(action.u(1,i)-((action.u(2,i)*0.254)/2)), vrep.simx_opmode_oneshot_wait);
        pause(0.5);
        
        %fprintf('Its Working Bro :D\n');
        %             [res,replyData]=vrep.simxQuery(clientID,'request','count','reply',1000);
        %             if (res==vrep.simx_error_noerror)
        %                 fprintf('count : %s\n',i);
        %                 %            sce = replyData;
        %                 %            fprintf('scene saved at location: %s\n', sce);
        %                 [res] = vrep.simxSetObjectPosition(clientID,bot,-1,[action.x(1,i),action.x(2,i),0.15],vrep.simx_opmode_oneshot_wait);
        %                 [res1] = vrep.simxSetObjectOrientation(clientID,bot,-1,[0,0,0],vrep.simx_opmode_oneshot_wait);
        %                 pause(2);
        %
        %             else fprintf('Its not Working Bro\n');
        %             end
    end
    
    pause(1);
    
    [res1] = vrep.simxStopSimulation(clientID, vrep.simx_opmode_oneshot_wait);
    fprintf('Simulation should stop now....\n');
    
    vrep.simxFinish(clientID);
    
else
    disp('Failed connecting to remote API server');
end
vrep.delete(); % explicitely call the destructor!
disp('Program ended');

