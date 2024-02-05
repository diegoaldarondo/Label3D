# Label3D

Label3D is a GUI for the manual labeling of 3D keypoints in multiple cameras.
![Label3D Animation](common/label3dAnimation.gif)

## Installation

Label3D is dependent on submodule git repositories. To install all dependencies, use:

```
git clone  --recurse-submodules https://github.com/diegoaldarondo/Label3D.git
```

Otherwise you can manually install dependencies.

```
git clone https://github.com/diegoaldarondo/Label3D.git
cd Label3D/deps
git clone https://github.com/diegoaldarondo/Animator.git
```

## Features
1. Simultaneous viewing of any number of camera views  
3. Multiview triangulation of 3D keypoints  
4. Point-and-click and draggable gestures to label keypoints  
5. Zooming, panning, and other default Matlab gestures  
6. Integration with `Animator` classes  

## Usage
Requires `Matlab 2019b`, `Matlab 2020a`, `Matlab 2020b` or later

Label3D takes a cell arrays of structs of camera parameters as in
https://github.com/spoonsso/DANNCE, a cell array of corresponding videos (h,w,c,N),
and a skeleton struct defining a directed graph. Please look at `example.m`
for examples on how to format data.

```
labelGui = Label3D(params, videos, skeleton);
```

## [Manual](https://github.com/diegoaldarondo/Label3D/wiki)
* [About](https://github.com/diegoaldarondo/Label3D/wiki/About)
* [Documentation](https://github.com/diegoaldarondo/Label3D/wiki/Documentation)
* [Gestures and hotkeys](https://github.com/diegoaldarondo/Label3D/wiki/Gestures-and-hotkeys)
* [Setup](https://github.com/diegoaldarondo/Label3D/wiki/Setup)


## FAQ

### Q: My label3d windows aren't closing properly
**A**: Try running the following commands in the matlab command window, to modify your 
    matlab startup script:

  1. Open the matlab startup script file for editing:  

      `edit(fullfile(userpath,'startup.m'))`  

  3. Put the following line in the file:
      
      `set(groot, 'defaultFigureCloseRequestFcn', 'close(gcf)');`
  
  4. Restart Matlab  


## Credits

Written by Diego Aldarondo (2019)  
Minor updates by Chris Axon (2024)

Some code adapted from https://github.com/talmo/leap
