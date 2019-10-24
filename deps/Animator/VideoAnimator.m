classdef VideoAnimator < Animator
    %VideoAnimator - interactive movie
    %Subclass of Animator.
    %
    %Syntax: VideoAnimator(V)
    %
    %VideoAnimator Properties:
    %   V - 4D (i,j,channel,N) movie to animate.
    %   img - Handle to the imshow object
    %   
    %
    %VideoAnimator Methods:
    %VideoAnimator - constructor
    %restrict - restrict animation to subset of frames
    %keyPressCalback - handle UI
    properties (Access = private)
        statusMsg = 'VideoAnimator:\nFrame: %d\nframeRate: %d\n';
        instructions = ['VideoAnimator Guide:\n' ...
            'rightarrow: next frame\n' ...
            'leftarrow: previous frame\n' ...
            'uparrow: increase frame rate\n' ...
            'downarrow: decrease frame rate\n' ...
            'space: set frame rate to 1\n' ...
            'control: set frame rate to 50\n' ...
            'shift: set frame rate to 250\n' ...
            'h: help guide\n' ...
            'r: reset\n' ...
            's: print current frame and rate\n'];
        MarkerSize = 30
        LineWidth = 3
    end
    
    properties (Access = public)
        V
        img
    end
    
    methods
        function obj = VideoAnimator(V, varargin)
            % User defined inputs
            if ~isempty(V)
                obj.V = V;
                % Handle 3 dimensional matrices as grayscale videos. 
                if numel(size(obj.V)) == 3
                    obj.V = reshape(obj.V,size(obj.V,1),size(obj.V,2),1,size(obj.V,3));
                end
            end
            if ~isempty(varargin)
                set(obj,varargin{:});
            end
            
            % Handle defaults
            if isempty(obj.nFrames)
                obj.nFrames = size(obj.V,4);
            end
            obj.frameInds = 1:obj.nFrames;   
            hold(obj.Axes,'off')
            obj.img = imshow(obj.V(:,:,:, obj.frame),'Parent',obj.Axes);
        end
        
        function restrict(obj, newFrames)
            restrict@Animator(obj, newFrames);
        end
        
        function keyPressCallback(obj,source,eventdata)
            % determine the key that was pressed
            keyPressCallback@Animator(obj,source,eventdata);
            keyPressed = eventdata.Key;
            switch keyPressed
                case 's'
                    fprintf(obj.statusMsg,...
                        obj.frameInds(obj.frame),obj.frameRate);
                case 'r'
                    reset(obj);
                case 'h'
                    fprintf(obj.instructions)
            end
            update(obj);
        end
    end
    
    methods (Access = private)
        function reset(obj)
            restrict(obj,1:size(obj.V,4));
        end
    end
    
    methods (Access = protected)
        function update(obj)
            set(obj.img,'CData',obj.V(:,:,:,  obj.frameInds(obj.frame)));
        end
    end
end