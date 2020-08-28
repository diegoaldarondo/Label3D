%% Test Class Definition
classdef Label3DTest < matlab.unittest.TestCase
    
    properties
        TestLabelGui
        params
        videos
        skeleton
    end
    
    methods (TestClassSetup)
        function addLabel3DClassToPath(testCase)
            p = path;
            testCase.addTeardown(@path,p);
            addpath(fullfile(pwd, 'test'));
            addpath(fullfile(pwd, 'skeletons'));
            addpath(genpath(fullfile(pwd, 'deps')));
        end
    end
    
    methods (TestMethodSetup)
        function createLabel3D(testCase)
            % Create the Label3D Gui
            % Load some helper data
            setup = load('test/test.mat');
            testCase.params = setup.params;
            testCase.videos = setup.videos;
            testCase.skeleton = load('rat16.m');
            testCase.labels1 = load('labels1.m');
            testCase.labels2 = load('labels2.m');
            testCase.TestLabelGui = ...
                Label3D(testCase.params, testCase.videos, testCase.skeleton);
        end
    end
    
    
    methods (TestMethodTeardown)
        function closeLabel3D(testCase)
            close(testCase.TestLabelGui)
        end
    end
    
    
    %% Test Method Block
    methods (Test)
        
        function testLabel3DConstruction1(testCase)
            close(testCase.TestLabelGui)
            testCase.TestLabelGui = Label3D(testCase.params, testCase.videos, testCase.skeleton);
        end
        
        function testLabel3DConstruction2(testCase)
            close(testCase.TestLabelGui)
            testCase.TestLabelGui = Label3D(testCase.videos);
        end
          
        
    end
end
