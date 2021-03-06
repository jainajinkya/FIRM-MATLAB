classdef MotionModel_class < MotionModel_interface
    % Note that because the class is defined as a handle class, the
    % properties must be defined such that they are do not change from an
    % object to another one.
    properties (Constant)
        stDim = state.dim; % state dimension
        ctDim = 4;  % control vector dimension
        wDim = 7;   % Process noise (W) dimension
        zeroControl = zeros(MotionModel_class.ctDim,1);
        zeroNoise = zeros(MotionModel_class.wDim,1);
        dt = user_data_class.par.motion_model_parameters.dt;
        l_1 = user_data_class.par.motion_model_parameters.distBetweenFrontWheels; % the distance between front wheels in cm
        l_2 =  user_data_class.par.motion_model_parameters.distBetweenFrontAndBackWheels; % the distance between front and back wheels in the same side in cm

        sigma_b_u = user_data_class.par.motion_model_parameters.sigma_b_u_KukaBase;
        eta_u = user_data_class.par.motion_model_parameters.eta_u_KukaBase;
        P_Wg = user_data_class.par.motion_model_parameters.P_Wg;
        
    end
    %     properties (Constant = true, SetAccess = private)
    %         UnDim = 3;
    %         WgDim = 3;
    %     end
    
    methods (Static)
        function x_next = f_discrete(x,u,w)
            Un = w(1:MotionModel_class.ctDim); % The size of Un may be different from ctDim in some other model.
            Wg = w(MotionModel_class.ctDim+1 : MotionModel_class.wDim); % The size of Wg may be different from stDim in some other model.
            Wc = MotionModel_class.f_contin(x,Un,Wg);
            x_next = x+MotionModel_class.f_contin(x,u,0)*MotionModel_class.dt+Wc*sqrt(MotionModel_class.dt);
        end
        function x_dot = f_contin(x,u,wg) % Do not call this function from outside of this class!! % The last input in this method should be w, instead of wg. But, since it is a only used in this class, it does not matter so much.
            l1 = MotionModel_class.l1;
            l2 = MotionModel_class.l2;
            gama1= 2/(l1+l2);
            x_dot = (1/4)*[1      -1     -1      1;...
                           1       1      1      1;...
                           -gmam1 gama1 -gama1 gama1]*u+wg;
        end
        function A = df_dx_func(x,u,w)
            un = w(1:MotionModel_class.ctDim); % The size of Un may be different from ctDim in some other model.
            wg = w(MotionModel_class.ctDim+1 : MotionModel_class.wDim); % The size of Wg may be different from stDim in some other model.
            A = eye(MotionModel_class.stDim) ...
                + MotionModel_class.df_contin_dx(x,u,zeros(MotionModel_class.stDim,1))*MotionModel_class.dt ...
                + MotionModel_class.df_contin_dx(x,un,wg)*sqrt(MotionModel_class.dt);
        end
        function Acontin = df_contin_dx(x,u,w) %#ok<INUSD>
            Acontin = zeros(3,3);
        end
        function B = df_du_func(x,u,w) %#ok<INUSD>
            l1 = MotionModel_class.l1;
            l2 = MotionModel_class.l2;
            gama1= 2/(l1+l2);
            B     = (1/4)*[1      -1     -1      1;...
                           1       1      1      1;...
                           -gmam1 gama1 -gama1 gama1]*MotionModel_class.dt;
            end
        function G = df_dw_func(x,u,w) %#ok<INUSD>
            B     = (1/4)*[1      -1     -1      1;...
                           1       1      1      1;...
                           -gmam1 gama1 -gama1 gama1]*MotionModel_class.dt;
            G = [B,eye(MotionModel_class.stDim)]*sqrt(MotionModel_class.dt);
        end
        function w = generate_process_noise(x,u) %#ok<INUSD>
            [Un,Wg] = generate_control_and_indep_process_noise(u);
            w = [Un;Wg];
        end
        function Q_process_noise = process_noise_cov(x,u) %#ok<INUSD>
            P_Un = control_noise_covariance(u);
            Q_process_noise = blkdiag(P_Un,MotionModel_class.P_Wg);
        end
        function nominal_traj = generate_open_loop_point2point_traj(X_initial,X_final) % generates open-loop trajectories between two start and goal states
            if isa(X_initial,'state'), X_initial=X_initial.val; end % retrieve the value of the state vector
            if isa(X_final,'state'), X_final=X_final.val; end % retrieve the value of the state vector
            % parameters
            omega_path=user_data_class.par.motion_model_parameters.omega_const_path; % constant rotational velocity during turnings
            dt=MotionModel_class.dt;
            V_path=user_data_class.par.motion_model_parameters.V_const_path; % constant translational velocity during straight movements
            stDim = MotionModel_class.stDim;
            ctDim=MotionModel_class.ctDim;
            r=MotionModel_class.robot_link_length;
            
            th_p = atan2( X_final(2)-X_initial(2)  ,  X_final(1)-X_initial(1)  ); % the angle of edge % note that "th_p" is already between -pi and pi, since it is the output of "atan2"
            %-------------- Rotation number of steps
            if abs(X_initial(3))>pi, X_initial(3)=(X_initial(3)-sign(X_initial(3))*2*pi); end % Here, we bound the initial angle "X_initial(3)" between -pi and pi
            if abs(X_final(3))>pi, X_final(3)=(X_final(3)-sign(X_final(3)*2*pi)); end % Here, we bound the final angle "X_final(3)" between -pi and pi
            delta_th_p = X_final(3) - X_initial(3); % turning angle
            if abs(delta_th_p)>pi, delta_th_p=(delta_th_p-sign(delta_th_p)*2*pi); end % Here, we bound "pre_delta_th_p" between -pi and pi
            rotation_steps = abs( delta_th_p/(omega_path*dt) );
            %--------------Translation number of steps
            delta_disp = norm( X_final(1:2) - X_initial(1:2) );
            translation_steps = abs(delta_disp/(V_path*dt));
            %--------------Total number of steps
            kf_rational = max([rotation_steps , translation_steps]);
            kf = floor(kf_rational)+1;  % note that in all following lines you cannot replace "floor(something)+1" by "ceil(something)", as it may be  a whole number.
            
            %=====================Rotation steps of the path
            delta_theta_const = omega_path*sign(delta_th_p)*dt;
            delta_theta_nominal(: , 1:floor(rotation_steps)) =  repmat( delta_theta_const , 1 , floor(rotation_steps));
            delta_theta_const_end = omega_path*sign(delta_th_p)*dt*(rotation_steps-floor(rotation_steps));
            delta_theta_nominal(:,floor(rotation_steps)+1) = delta_theta_const_end; % note that you cannot replace "floor(pre_rotation_steps)+1" by "ceil(pre_rotation_steps)", as it may be  a whole number.
            delta_theta_nominal = [delta_theta_nominal , zeros(1 , kf - size(delta_theta_nominal,2))]; % augment zeros to the end of "delta_theta_nominal", to make its length equal to "kf".
            
%             u_const = ones(3,1)*r*omega_path*sign(delta_th_p);
%             u_p_rot(: , 1:floor(rotation_steps)) = repmat( u_const,1,floor(rotation_steps) );
%             u_const_end = ones(3,1)*r*omega_path*sign(delta_th_p)*(rotation_steps-floor(rotation_steps));
%             u_p_rot(:,floor(rotation_steps)+1)=u_const_end; % note that you cannot replace "floor(pre_rotation_steps)+1" by "ceil(pre_rotation_steps)", as it may be  a whole number.
            
            %=====================Translations
             delta_xy_const = [V_path*cos(th_p);V_path*sin(th_p)]*dt;
             delta_xy_nominal( : , 1:floor(translation_steps) ) = repmat( delta_xy_const , 1 , floor(translation_steps));
             delta_xy_const_end = [V_path*cos(th_p);V_path*sin(th_p)]*dt*(translation_steps - floor(translation_steps));
             delta_xy_nominal( : , floor(translation_steps)+1 ) = delta_xy_const_end;
            delta_xy_nominal = [delta_xy_nominal , zeros(2 , kf - size(delta_xy_nominal,2))]; % augment zeros to the end of "delta_xy_nominal", to make its length equal to "kf".
            
            
            delta_state_nominal = [delta_xy_nominal;delta_theta_nominal];
            
            %=====================Nominal control and state trajectory generation
            x_p = zeros(stDim,kf+1);
            theta = zeros(1,kf+1);
            u_p = zeros(stDim,kf);
            
            x_p(:,1) = X_initial;
            theta(1) = X_initial(3);
            for k = 1:kf
                theta(:,k+1) = theta(:,k) + delta_state_nominal(3,k);
                th_k = theta(:,k);
                T_inv_k = [-sin(th_k),     cos(th_k)       ,r;
                 -sin(pi/3-th_k),-cos(pi/3-th_k) ,r;
                 sin(pi/3+th_k) ,-cos(pi/3+th_k) ,r];
             
                delta_body_velocities_k = delta_state_nominal(:,k)/dt; % x,y,and theta velocities in body coordinate at time step k
                u_p(:,k) = T_inv_k*delta_body_velocities_k;  % "T_inv_k" maps the "velocities in body coordinate" to the control signal
             
                x_p(:,k+1) = x_p(:,k) + delta_state_nominal(:,k);
            end
            
            % noiselss motion  % for debug: if you uncomment the following
            % lines you have to get the same "x_p_copy" as the "x_p"
            %             x_p_copy = zeros(stDim,kf+1);
            %             x_p_copy(:,1) = X_initial;
            %             for k = 1:kf
            %                 x_p_copy(:,k+1) = MotionModel_class.f_discrete(x_p_copy(:,k),u_p(:,k),zeros(MotionModel_class.wDim,1));
            %             end
            
            nominal_traj.x = x_p;
            nominal_traj.u = u_p;
        end
        function nominal_traj = generate_VALID_open_loop_point2point_traj(X_initial,X_final) % generates open-loop trajectories between two start and goal states
            if isa(X_initial,'state'), X_initial=X_initial.val; end % retrieve the value of the state vector
            if isa(X_final,'state'), X_final=X_final.val; end % retrieve the value of the state vector
            % parameters
            omega_path=user_data_class.par.motion_model_parameters.omega_const_path; % constant rotational velocity during turnings
            dt=MotionModel_class.dt;
            V_path=user_data_class.par.motion_model_parameters.V_const_path; % constant translational velocity during straight movements
            stDim = MotionModel_class.stDim;
            ctDim=MotionModel_class.ctDim;
            r=MotionModel_class.robot_link_length;
            
            th_p = atan2( X_final(2)-X_initial(2)  ,  X_final(1)-X_initial(1)  ); % the angle of edge % note that "th_p" is already between -pi and pi, since it is the output of "atan2"
            %-------------- Rotation number of steps
            if abs(X_initial(3))>pi, X_initial(3)=(X_initial(3)-sign(X_initial(3))*2*pi); end % Here, we bound the initial angle "X_initial(3)" between -pi and pi
            if abs(X_final(3))>pi, X_final(3)=(X_final(3)-sign(X_final(3)*2*pi)); end % Here, we bound the final angle "X_final(3)" between -pi and pi
            delta_th_p = X_final(3) - X_initial(3); % turning angle
            if abs(delta_th_p)>pi, delta_th_p=(delta_th_p-sign(delta_th_p)*2*pi); end % Here, we bound "pre_delta_th_p" between -pi and pi
            rotation_steps = abs( delta_th_p/(omega_path*dt) );
            %--------------Translation number of steps
            delta_disp = norm( X_final(1:2) - X_initial(1:2) );
            translation_steps = abs(delta_disp/(V_path*dt));
            %--------------Total number of steps
            kf_rational = max([rotation_steps , translation_steps]);
            kf = floor(kf_rational)+1;  % note that in all following lines you cannot replace "floor(something)+1" by "ceil(something)", as it may be  a whole number.
            
            %=====================Rotation steps of the path
            delta_theta_const = omega_path*sign(delta_th_p)*dt;
            delta_theta_nominal(: , 1:floor(rotation_steps)) =  repmat( delta_theta_const , 1 , floor(rotation_steps));
            delta_theta_const_end = omega_path*sign(delta_th_p)*dt*(rotation_steps-floor(rotation_steps));
            delta_theta_nominal(:,floor(rotation_steps)+1) = delta_theta_const_end; % note that you cannot replace "floor(pre_rotation_steps)+1" by "ceil(pre_rotation_steps)", as it may be  a whole number.
            delta_theta_nominal = [delta_theta_nominal , zeros(1 , kf - size(delta_theta_nominal,2))]; % augment zeros to the end of "delta_theta_nominal", to make its length equal to "kf".
            
%             u_const = ones(3,1)*r*omega_path*sign(delta_th_p);
%             u_p_rot(: , 1:floor(rotation_steps)) = repmat( u_const,1,floor(rotation_steps) );
%             u_const_end = ones(3,1)*r*omega_path*sign(delta_th_p)*(rotation_steps-floor(rotation_steps));
%             u_p_rot(:,floor(rotation_steps)+1)=u_const_end; % note that you cannot replace "floor(pre_rotation_steps)+1" by "ceil(pre_rotation_steps)", as it may be  a whole number.
            
            %=====================Translations
             delta_xy_const = [V_path*cos(th_p);V_path*sin(th_p)]*dt;
             delta_xy_nominal( : , 1:floor(translation_steps) ) = repmat( delta_xy_const , 1 , floor(translation_steps));
             delta_xy_const_end = [V_path*cos(th_p);V_path*sin(th_p)]*dt*(translation_steps - floor(translation_steps));
             delta_xy_nominal( : , floor(translation_steps)+1 ) = delta_xy_const_end;
            delta_xy_nominal = [delta_xy_nominal , zeros(2 , kf - size(delta_xy_nominal,2))]; % augment zeros to the end of "delta_xy_nominal", to make its length equal to "kf".
            
            
            delta_state_nominal = [delta_xy_nominal;delta_theta_nominal];
            
            %=====================Nominal control and state trajectory generation
            x_p = zeros(stDim,kf+1);
            theta = zeros(1,kf+1);
            u_p = zeros(stDim,kf);
            
            x_p(:,1) = X_initial;
            theta(1) = X_initial(3);
            for k = 1:kf
                theta(:,k+1) = theta(:,k) + delta_state_nominal(3,k);
                th_k = theta(:,k);
                T_inv_k = [-sin(th_k),     cos(th_k)       ,r;
                 -sin(pi/3-th_k),-cos(pi/3-th_k) ,r;
                 sin(pi/3+th_k) ,-cos(pi/3+th_k) ,r];
             
                delta_body_velocities_k = delta_state_nominal(:,k)/dt; % x,y,and theta velocities in body coordinate at time step k
                u_p(:,k) = T_inv_k*delta_body_velocities_k;  % "T_inv_k" maps the "velocities in body coordinate" to the control signal
             
                x_p(:,k+1) = x_p(:,k) + delta_state_nominal(:,k);
                %                 tmp.draw(); % FOR DEBUGGING
                tmp = state(x_p(:,k+1)); if tmp.is_constraint_violated, nominal_traj =[]; return; end
            
            end
            
            % noiselss motion  % for debug: if you uncomment the following
            % lines you have to get the same "x_p_copy" as the "x_p"
            %             x_p_copy = zeros(stDim,kf+1);
            %             x_p_copy(:,1) = X_initial;
            %             for k = 1:kf
            %                 x_p_copy(:,k+1) = MotionModel_class.f_discrete(x_p_copy(:,k),u_p(:,k),zeros(MotionModel_class.wDim,1));
            %             end
            
            nominal_traj.x = x_p;
            nominal_traj.u = u_p;
        end
        function YesNo = is_constraints_violated(open_loop_traj) % this function checks if the "open_loop_traj" violates any constraints or not. For example it checks collision with obstacles.
            % In this class the open loop trajectories are indeed straight
            % lines. So, we use following simplified procedure to check the
            % collisions.
            Obst=obstacles_class.obst;
            edge_start = open_loop_traj.x(1:2,1);
            edge_end = open_loop_traj.x(1:2,end);
            
            N_obst=size(Obst,2);
            intersection=0;
            for ib=1:N_obst
                X_obs=[Obst{ib}(:,1);Obst{ib}(1,1)];
                Y_obs=[Obst{ib}(:,2);Obst{ib}(1,2)];
                X_edge=[edge_start(1);edge_end(1)];
                Y_edge=[edge_start(2);edge_end(2)];
                [x_inters,~] = polyxpoly(X_obs,Y_obs,X_edge,Y_edge);
                if ~isempty(x_inters)
                    intersection=intersection+1;
                end
            end
            if intersection>0
                YesNo=1;
            else
                YesNo=0;
            end
        end
        function traj_plot_handle = draw_nominal_traj(nominal_traj, varargin)
            s_node_2D_loc = nominal_traj.x(1:2,1);
            e_node_2D_loc = nominal_traj.x(1:2,end);
            % retrieve PRM parameters provided by the user
            disp('the varargin need to be parsed here')
%             edge_spec = obj.par.edge_spec;
%             edge_width = obj.par.edge_width;
            edge_spec = '-b';
            edge_width = 2;

            % drawing the 2D edge line
            traj_plot_handle = plot([s_node_2D_loc(1),e_node_2D_loc(1)],[s_node_2D_loc(2),e_node_2D_loc(2)],edge_spec,'linewidth',edge_width);
        end
    end
    
    methods (Access = private)
        function nominal_traj = generate_open_loop_point2point_traj_turn_move_turn(obj , start_node_ind, end_node_ind)
            % I do not use this function anymore. But I kept it for future
            % references.
            X_initial = obj.nodes(start_node_ind).val;
            X_final = obj.nodes(end_node_ind).val;
            
            % parameters
            omega_path=user_data_class.par.motion_model_parameters.omega_const_path; % constant rotational velocity during turnings
            dt=user_data_class.par.motion_model_parameters.dt;
            V_path=user_data_class.par.motion_model_parameters.V_const_path; % constant translational velocity during straight movements
            stDim = MotionModel_class.stDim;
            ctDim=MotionModel_class.ctDim;
            r=MotionModel_class.robot_link_length;
            
            th_p = atan2( X_final(2)-X_initial(2)  ,  X_final(1)-X_initial(1)  ); % the angle of edge % note that "th_p" is already between -pi and pi, since it is the output of "atan2"
            %--------------Pre-Rotation number of steps
            if abs(X_initial(3))>pi, X_initial(3)=(X_initial(3)-sign(X_initial(3))*2*pi); end % Here, we bound the initial angle "X_initial(3)" between -pi and pi
            pre_delta_th_p = th_p - X_initial(3); % turning angle at the beginning of the edge (to align robot with edge)
            if abs(pre_delta_th_p)>pi, pre_delta_th_p=(pre_delta_th_p-sign(pre_delta_th_p)*2*pi); end % Here, we bound "pre_delta_th_p" between -pi and pi
            pre_rotation_steps = abs( pre_delta_th_p/(omega_path*dt) );
            %--------------Translation number of steps
            delta_disp = norm( X_final(1:2) - X_initial(1:2) );
            translation_steps = abs(delta_disp/(V_path*dt));
            %--------------Post-Rotation number of steps
            if abs(X_final(3))>pi, X_final(3)=(X_final(3)-sign(X_final(3)*2*pi)); end % Here, we bound the initial angle "X_final(3)" between -pi and pi
            post_delta_th_p =   X_final(3) - th_p; % turning angle at the end of the edge (to align robot with the end node)
            if abs(post_delta_th_p)>pi, post_delta_th_p=(post_delta_th_p-sign(post_delta_th_p)*2*pi); end % Here, we bound "post_delta_th_p" between -pi and pi
            post_rotation_steps = abs( post_delta_th_p/(omega_path*dt) );
            %--------------Total number of steps
            kf = floor(pre_rotation_steps)+1+floor(translation_steps)+1+floor(post_rotation_steps)+1;
            u_p=nan(ctDim,kf+1);
            
            %=====================Pre-Rotation
            u_const = ones(3,1)*r*omega_path*sign(pre_delta_th_p);
            u_p(: , 1:floor(pre_rotation_steps)) = repmat( u_const,1,floor(pre_rotation_steps) );
            u_const_end = ones(3,1)*r*omega_path*sign(pre_delta_th_p)*(pre_rotation_steps-floor(pre_rotation_steps));
            u_p(:,floor(pre_rotation_steps)+1)=u_const_end; % note that you cannot replace "floor(pre_rotation_steps)+1" by "ceil(pre_rotation_steps)", as it may be  a whole number.
            last_k = floor(pre_rotation_steps)+1;
            %=====================Translations
             T_inv = [-sin(th_p),     cos(th_p)       ,r;
                 -sin(pi/3-th_p),-cos(pi/3-th_p) ,r;
                 sin(pi/3+th_p) ,-cos(pi/3+th_p) ,r];
            u_const=T_inv*[V_path*cos(th_p);V_path*sin(th_p);0];
            u_p( : , last_k+1:last_k + floor(translation_steps) ) = repmat(u_const,1,floor(translation_steps));
            %Note that in below line we are using "u_const", in which the "Inv_Dyn"
            %has been already accounted for. So, we do not need to multiply it with
            %"Inv_Dyn" again.
            u_const_end = u_const*(translation_steps - floor(translation_steps));
            u_p( : , last_k + floor(translation_steps)+1 ) = u_const_end;
            %=====================Post-Rotation
            last_k = last_k + floor(translation_steps)+1;
            u_const = ones(3,1)*r*omega_path*sign(post_delta_th_p);
            u_p(: , last_k+1:last_k+floor(post_rotation_steps)) = repmat( u_const,1,floor(post_rotation_steps) );
            u_const_end = ones(3,1)*r*omega_path*sign(post_delta_th_p)*(post_rotation_steps-floor(post_rotation_steps));
            u_p(:,last_k+floor(post_rotation_steps)+1)=u_const_end; % note that you cannot replace "floor(pre_rotation_steps)+1" by "ceil(pre_rotation_steps)", as it may be  a whole number.
            
            % noiselss motion
            x_p = zeros(stDim,kf+1);
            x_p(:,1) = X_initial;
            for k = 1:kf
                x_p(:,k+1) = MotionModel_class.f_discrete(x_p(:,k),u_p(:,k),zeros(MotionModel_class.wDim,1));
            end
            
            nominal_traj.x = x_p;
            nominal_traj.u = u_p;
        end
    end
end


function [Un,Wg] = generate_control_and_indep_process_noise(U)
% generate Un
indep_part_of_Un = randn(MotionModel_class.ctDim,1);
P_Un = control_noise_covariance(U);
Un = indep_part_of_Un.*diag(P_Un.^(1/2));
% generate Wg
Wg = mvnrnd(zeros(MotionModel_class.stDim,1),MotionModel_class.P_Wg)';
end
function P_Un = control_noise_covariance(U)
u_std=(MotionModel_class.eta_u).*U+(MotionModel_class.sigma_b_u);
P_Un=diag(u_std.^2);
end