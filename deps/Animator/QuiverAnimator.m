classdef QuiverAnimator < Animator
    %QuiverAnimator - Interactive animation of points moving through a 
    %vector field
    %Subclass of Animator.
    %
    %Syntax: QuiverAnimator('data',data)
    %
    %QuiverAnimator Properties:
    %   data - dataded points (replicated so size matches nFrames)
    %   scatterFig - handle to the background scatter plot
    %   currentPoint - handle to the current point
    %   poly - polygon defined in user input. 
    %   step - stepsize between grid points in calculating vector field
    %          (smaller stepsize takes longer and renders more lines)
    %   vectorSize - size of unit vectors
    %   normVectors - 1 or 0, if 1 normalize vectors to unit length,
    %                 otherwise use speed as the magnitude of the vector.
    %   cmap - colormap to use for vectorfield.
    %   dataX - X dimension of datading
    %   dataY - Y dimension of datading
    %   quiver - Handle to quiverc object
    %   orderPoints - Order points by dimension
    %
    %QuiverAnimator Methods:
    %QuiverAnimator - constructor
    %restrict - restrict animation to subset of frames
    %keyPressCalback - handle UI
    properties (Access = private)
        instructions = ['QuiverAnimator Guide:\n' ...
            'rightarrow: next frame\n' ...
            'leftarrow: previous frame\n' ...
            'uparrow: increase frame rate by 10\n' ...
            'downarrow: decrease frame rate by 10\n' ...
            'space: set frame rate to 1\n' ...
            'control: set frame rate to 50\n' ...
            'shift: set frame rate to 250\n' ...
            'h: help guide\n' ...
            'i: input polygon\n' ...
            'r: reset\n' ...
            's: print current matched frame and rate\n'];
        statusMsg = 'dataMovie:\nFrame: %d\nframeRate: %d\n';
        pointsInPoly
        behaviorWindow = 0:0;
    end
    
    properties (Access = public)
        data
        poly
        step=.75;
        vectorSize = 1;
        normVectors = 1;
        densityThresh = 3;
        cmap = @magma;
        dataX
        dataY
        quiver
        currentPoint
        smooth = false;
    end
    
    methods
        function obj = QuiverAnimator(data, varargin)
            if ~isempty(data)
                obj.data = data;
            end
            % User defined inputs
            if ~isempty(varargin)
                set(obj,varargin{:});
            end
            % Handle defaults
            if isempty(obj.nFrames)
                obj.nFrames = size(obj.data,1);
            end
            obj.frameInds = 1:obj.nFrames;
            
            % Create the backgound quiver
            set(obj.Parent,'CurrentAxes',obj.Axes)
            if obj.smooth
                X = smoothdata(obj.data(:,1),'gaussian',5);
                Y = smoothdata(obj.data(:,2),'gaussian',5);
            else
                X = obj.data(:,1);
                Y = obj.data(:,2);
            end
            [gX, gY, gdX, gdY] = ...
                quiverVars(X,Y,'step',obj.step,'densityThresh',obj.densityThresh,'ubound',100,'lbound',0);
            obj.quiver = quiverc(gX,gY,gdX,gdY,'NormVectors',obj.normVectors,'VectorSize',obj.vectorSize,'cmap',obj.cmap);
            xlim(obj.Axes,[min(obj.data(:,1)) max(obj.data(:,1))])
            ylim(obj.Axes,[min(obj.data(:,2)) max(obj.data(:,2))])
            
            obj.dataX = obj.data(:,1);
            obj.dataY = obj.data(:,2);
            % Plot the current point
            obj.currentPoint = scatter(obj.Axes,obj.dataX(1),...
                obj.dataY(1), 500,'w.');

        end
        
        function keyPressCallback(obj,source,eventdata)
            % determine the key that was pressed
            keyPressCallback@Animator(obj,source,eventdata);
            keyPressed = eventdata.Key;
            switch keyPressed
                case 'h'
                    fprintf(obj.instructions);
                case 's'
                    fprintf(obj.statusMsg,...
                        obj.frameInds(obj.frame),obj.frameRate);
                    fprintf('counter: %d\n', obj.frame)
                case 'i'
                    inputPoly(obj);
                case 'y'
                    if obj.scope == obj.id
                        orderPoints(obj,2);
                    end
                case 'x'
                    if obj.scope == obj.id
                        orderPoints(obj,1);
                    end
                case 'r'
                    reset(obj);
            end
            update(obj);
        end
        
        function inputPoly(obj)
            if obj.scope == obj.id
                % Draw a poly and find the points within.
                if isempty(obj.poly)
                    obj.poly = drawpolygon(obj.Axes,'Color','w');
                else
                    obj.poly = drawpolygon(obj.Axes,'Color','w','Position',obj.poly.Position);
                end
                xv = obj.poly.Position(:,1);
                yv = obj.poly.Position(:,2);
                obj.pointsInPoly = inpolygon(obj.data(:,1),...
                    obj.data(:,2),xv,yv);
                
                % Find a window surrounding the frames within the polygon.
                framesInPoly = obj.frameInds(obj.pointsInPoly);
                framesInPoly = unique(framesInPoly);
                framesInPoly = framesInPoly + obj.behaviorWindow;
                framesInPoly = unique(sort(framesInPoly(:)));
                framesInPoly = framesInPoly((framesInPoly > 0) &...
                    (framesInPoly <= numel(obj.frameInds)));
                if ~isempty(obj.links)
                    for i = 1:numel(obj.links)
                        restrict(obj.links{i}, framesInPoly)
                    end
                else
                    restrict(obj,framesInPoly);
                end
            end
        end
    end
    
    methods (Access = private)
        function reset(obj)
            if ~isempty(obj.poly)
                delete(obj.poly)
                obj.poly = [];
            end           
            % Set dataMovie and associated MarkerMovies to the orig. size
            restrict(obj,1:size(obj.data,1));
        end
           
        function orderPoints(obj, dim)
            if dim == 1
                [~,I] = sort(obj.dataX(obj.frameInds));
            elseif dim == 2
                [~,I] = sort(obj.dataY(obj.frameInds));
            else
                error('dim must be 1 or 2')
            end
            
            reorderedFrames = obj.frameInds(I);
            % Restrict associated Animations to those frames
            if ~isempty(obj.links)
                for i = 1:numel(obj.links)
                    restrict(obj.links{i},reorderedFrames)
                end
            else
                restrict(obj,reorderedFrames);
            end
            
        end  
    end
    
    methods (Access = protected)
        function update(obj)
            set(obj.currentPoint,'XData',obj.dataX(obj.frameInds(obj.frame)),...
                'YData',obj.dataY(obj.frameInds(obj.frame)));
        end
    end
end