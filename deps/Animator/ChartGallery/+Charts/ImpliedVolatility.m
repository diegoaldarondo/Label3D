classdef ImpliedVolatility < Chart
    %IMPLIEDVOLATILITY Chart managing 3D scattered data comprising strike
    %price, time to expiry and implied volatility, together with an
    %interpolated implied volatility surface.
    %
    % Copyright 2018 The MathWorks, Inc.
    
    properties ( Hidden, Constant )
        % Product dependencies.
        Dependencies = ...
            {'MATLAB', 'Statistics and Machine Learning Toolbox', ...
            'Optimization Toolbox', 'Financial Toolbox', ...
            'Financial Instruments Toolbox'};
    end % properties ( Hidden, Constant )
    
    % Public interface properties.
    properties ( Dependent )
        % Table of option data, comprising the time to expiry, strike price
        % and implied volatility.
        OptionData
        % Axes x-label.
        XLabel
        % Axes y-label.
        YLabel
        % Axes z-label.
        ZLabel
        % Axes title.
        Title
        % Marker for the scattered data.
        Marker
        % Size of the markers.
        MarkerSize
        % Marker face color.
        MarkerFaceColor
        % Marker edge color.
        MarkerEdgeColor
        % Surface colormap.
        Colormap
        % Volatility curve interpolation method.
        InterpolationMethod
    end % properties ( Dependent )
    
    properties ( Access = private )
        % Backing property for the option data.
        OptionData_ = table.empty( 0, 4 );
        % Backing property for the colormap.
        Colormap_ = cool( 500 );
        % Backing property for the interpolation method.
        InterpolationMethod_ = 'pchip';
        % Implied volatility surface.
        Surface
        % 3D scattered data, plotted using a line object.
        Line
    end % properties ( Access = private )
    
    properties ( Dependent, Access = private )
        % Vector of unique expiry times.
        UniqueExpiryTimes
        % Vector of finely subdivided strike prices.
        FineStrike
        % Surface z-data (implied volatilities).
        VolatilityGrid
    end % properties ( Dependent, Access = private )
    
    methods
        
        function obj = ImpliedVolatility( varargin )            
           
            % Create the chart graphics.            
            obj.Line = line( 'Parent', obj.Axes, ...
                'XData', [], ...
                'YData', [], ...
                'ZData', [], ...
                'Marker', '.', ...
                'Color', 'k', ...
                'LineStyle', 'none' );
            obj.Surface = surface( obj.Axes, [], [], [], [], ...
                'FaceColor', 'interp', ...
                'EdgeAlpha', 0 );
            % Configure the chart's axes.
            view( obj.Axes, 3 );
            obj.Axes.XGrid = 'on';
            obj.Axes.YGrid = 'on';
            obj.Axes.ZGrid = 'on';           
                        
            % Set the chart properties.
            if ~isempty( varargin )
                set( obj, varargin{:} );
            end % if
            
        end % constructor
        
        % Get/set methods.
        function d = get.OptionData( obj )
            d = obj.OptionData_;
        end % get.OptionData
        
        function set.OptionData( obj, optionData )
            
           % Check that the option data is a table with three columns.
            validateattributes( optionData, {'table'}, ...
                {'nonempty', 'size', [NaN, 4]}, ...
                'ImpliedVolatility/set.OptionData', 'the option data' )
            % Validate the required attributes of the three table
            % variables.
            expiryTime = optionData.(1);
                        validateattributes( expiryTime, {'double'}, ...
                {'real', 'finite', 'nonnegative', 'vector'}, ...
                'ImpliedVolatility/set.OptionData', 'the expiry times' )
            strike = optionData.(2);
            validateattributes( strike, {'double'}, ...
                {'real', 'finite', 'positive', 'vector'}, ...
                'ImpliedVolatility/set.OptionData', 'the strike prices' )
            volatility = optionData.(3);
            validateattributes( volatility, {'double'}, ...
                {'real', 'finite', 'positive', 'vector', ...
                '<=', 100}, ...
                'ImpliedVolatility/set.OptionData', 'the volatilities' )
            assetPrice = optionData.(4);
            validateattributes( assetPrice, {'double'}, ...
                {'real', 'finite', 'positive', 'vector'}, ...
                'ImpliedVolatility/set.OptionData', 'the asset prices' )
            
            % Set the internal data property.
            obj.OptionData_ = optionData;
            
            % Update the chart.
            update( obj );
            
        end % set.OptionData        
        
        function xl = get.XLabel( obj )
            xl = obj.Axes.XLabel;
        end % get.XLabel
        
        function set.XLabel( obj, proposedXLabel )
            obj.Axes.XLabel = proposedXLabel;
        end % set.XLabel
        
        function yl = get.YLabel( obj )
            yl = obj.Axes.YLabel;
        end % get.YLabel
        
        function set.YLabel( obj, proposedYLabel )
            obj.Axes.YLabel = proposedYLabel;
        end % set.YLabel
        
        function zl = get.ZLabel( obj )
            zl = obj.Axes.ZLabel;
        end % get.ZLabel
        
        function set.ZLabel( obj, proposedZLabel )
            obj.Axes.ZLabel = proposedZLabel;
        end % set.ZLabel
        
        function t = get.Title( obj )
            t = obj.Axes.Title;
        end % get.Title
        
        function set.Title( obj, proposedTitle )
            obj.Axes.Title = proposedTitle;
        end % set.Title
        
        function m = get.Marker( obj )
            m = obj.Line.Marker;
        end % get.Marker
        
        function set.Marker( obj, proposedMarker )
            obj.Line.Marker = proposedMarker;
        end % set.Marker
        
        function ms = get.MarkerSize( obj )
            ms = obj.Line.MarkerSize;
        end % get.MarkerSize
        
        function set.MarkerSize( obj, proposedSize )
            obj.Line.MarkerSize = proposedSize;
        end % set.MarkerSize
        
        function mfc = get.MarkerFaceColor( obj )
            mfc = obj.Line.MarkerFaceColor;
        end % get.MarkerFaceColor
        
        function set.MarkerFaceColor( obj, proposedColor )
            obj.Line.MarkerFaceColor = proposedColor;
        end % set.MarkerFaceColor
        
        function mec = get.MarkerEdgeColor( obj )
            mec = obj.Line.MarkerEdgeColor;
        end % get.MarkerEdgeColor
        
        function set.MarkerEdgeColor( obj, proposedColor )
            obj.Line.MarkerEdgeColor = proposedColor;
        end % set.MarkerEdgeColor
        
        function cmap = get.Colormap( obj )
            cmap = obj.Colormap_;
        end % get.Colormap
        
        function set.Colormap( obj, proposedColormap )
            colormap( obj.Axes, proposedColormap )
            obj.Colormap_ = proposedColormap;
        end % set.Colormap
        
        function m = get.InterpolationMethod( obj )
            m = obj.InterpolationMethod_;
        end % get.InterpolationMethod
        
        function set.InterpolationMethod( obj, proposedMethod )
            % Validate the proposed method.
            validateattributes( proposedMethod, {'char'}, ...
                {'row', 'nonempty'}, ...
                'ImpliedVolatility/set.InterpolationMethod', ...
                'the interpolation method' )
            m = validatestring( proposedMethod, ...
                {'linear', 'spline', 'pchip', 'Hagan2002', 'Obloj2008'}, ...
                'ImpliedVolatility/set.InterpolationMethod', ...
                'the interpolation method' );
            
            % Assign the method.
            obj.InterpolationMethod_ = m;
            
            % Update the chart.
            update( obj );
        end % set.InterpolationMethod
        
        function t = get.UniqueExpiryTimes( obj )
            t = unique( obj.OptionData_.(1) );
        end % get.UniqueExpiryTimes
        
        function fs = get.FineStrike( obj )
            % Take the maximal interior domain of the strike prices across
            % each unique expiry time.
            T = obj.UniqueExpiryTimes;
            for k = numel( T ) : -1 : 1
                currentTIdx = obj.OptionData_.(1) == T(k);
                K = obj.OptionData_.(2);
                mn(k, 1) = min( K(currentTIdx) );
                mx(k, 1) = max( K(currentTIdx) );
            end
            mn = max( mn );
            mx = min( mx );            
            fs = linspace( mn, mx, 500 ).';
        end % get.FineStrike
        
        function sigma = get.VolatilityGrid( obj )
            
            % For each unique expiry time, we interpolate the corresponding
            % volatility smile over the fine strike prices.
            T = obj.UniqueExpiryTimes;
            K = obj.FineStrike;
            interpMethod = obj.InterpolationMethod;
            sigma = NaN( numel( K ), numel( T ) );
            switch interpMethod
                % Use INTERP1 to cover the basic cases.
                case {'linear', 'spline', 'pchip'}
                    for k = 1 : numel( T )
                        currentTIdx = obj.OptionData_.(1) == T(k);
                        currentK = obj.OptionData_{currentTIdx, 2};                        
                        currentVol = obj.OptionData_{currentTIdx, 3};
                        sigma(:, k) = interp1( currentK, currentVol, ...
                            K, interpMethod );
                    end % for
                    % Otherwise, we calibrate and evaluate the SABR model to
                    % obtain the implied volatilities.
                case {'Hagan2002', 'Obloj2008'}
                    sigma = sabr( obj );
                otherwise
                    error( 'ImpliedVolatility:InvalidInterpMethod', ...
                        'Unrecognized interpolation method %s.', ...
                        interpMethod )
            end % switch/case
            
            % Ensure that all computed volatilities are nonnegative.
            sigma = max( sigma, 0 );
            
        end % get.VolatilityGrid
        
    end % methods
    
    methods ( Access = private )
        
        function update( obj )
            
            % Update the discrete data markers.
            set( obj.Line, 'XData', obj.OptionData_.(1), ...
                'YData', obj.OptionData_.(2), ...
                'ZData', obj.OptionData_.(3) )
            % Update the volatility surface.
            set( obj.Surface, 'XData', obj.UniqueExpiryTimes, ...
                'YData', obj.FineStrike, ...
                'ZData', obj.VolatilityGrid, ...
                'CData', obj.VolatilityGrid )
            
        end % update
        
        function sigma = sabr( obj )
            % Define the settlement date (an arbitrary date since we are
            % working with times to expiry). The exercise date will be the
            % settlement date plus the time to expiry.
            settle = datetime( 2000, 1, 1 );
            % For each unique time to expiry, we calibrate the SABR model
            % The calibrated SABR model is then used to interpolate the 
            % implied volatilities across the range of finely subdivided 
            % strike prices.
            T = obj.UniqueExpiryTimes;
            for k = numel( T ) : -1 : 1
                % Compute the exercise date.
                exercise = settle + years( T(k) );
                % Extract the (K, sigma) values for each expiry time.
                currentTIdx = obj.OptionData_.(1) == T(k);
                strike = obj.OptionData_{currentTIdx, 2};
                vol = obj.OptionData_{currentTIdx, 3};
                underlyingPrice = obj.OptionData_{currentTIdx, 4};                
                % Calibrate the other parameters alpha, rho and nu using
                % nonlinear least squares.
                objFun = @(X) vol - ...
                    blackvolbysabr( X(1), X(2), X(3), X(4), settle, ...
                    exercise, underlyingPrice, strike, ...
                    'Model', obj.InterpolationMethod );
                opts = optimoptions( 'lsqnonlin', 'Display', 'off' );
                X = lsqnonlin( objFun, [0.5, 0.2, 0, 0.5], ...
                    [0, 0, -1, 0], [Inf, 1, 1, Inf], opts );
                % Interpolate the volatilities using the calibrated model.
                sigma(:, k) = blackvolbysabr( ...
                    X(1), X(2), X(3), X(4), ...
                    settle, exercise, mean(underlyingPrice), obj.FineStrike );
            end % for
            
        end % sabr        
        
    end % methods ( Access = private )
    
end % class definition