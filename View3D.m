classdef View3D < Label3D
    methods
        function saveState(obj)
            % Override superclass to do nothing
        end
%         function linkAnimators(obj)
%             Animator.linkAll([obj.h {obj} {obj.kp3a}])
%         end
        function animators = getAnimators(obj)
            animators = [obj.h {obj} {obj.kp3a}];
        end
    end
      
    methods (Access = protected)
        function updateStatusAnimator(obj)
            % Ovverride superclass to do nothing
        end
        function setUpKeypointTable(obj)
            % Override superclass to do nothing
        end
        function setUpStatusTable(obj)
            % Override superclass to do nothing
        end
    end
end