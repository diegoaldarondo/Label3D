# Label3D

Label3D is a GUI for the manual labeling of 3D keypoints in multiple cameras.
![Label3D Animation](common/label3dAnimation.gif)

## Features
1. Simultaneous viewing of any number of camera views
2. Multiview triangulation of 3D keypoints
3. Point-and-click and draggable gestures to label keypoints
4. Zooming, panning, and other default Matlab gestures
5. Integration with `Animator` classes


## Usage
Requires `Matlab 2019a` or `Matlab 2019b`

Label3D takes a cell arrays of structs of camera parameters as in
https://github.com/spoonsso/DANNCE, a cell array of corresponding videos (h,w,c,N),
and a skeleton struct defining a directed graph. Please look at `example.m`
for examples on how to format data.

```
labelGui = Label3D(params, videos, skeleton);
```

## Instructions
**right**: move forward one frameRate<br>
**left**: move backward one frameRate<br>
**up**: increase the frameRate<br>
**down**: decrease the frameRate<br>
**t**: triangulate points in current frame that have been labeled in at least two images and reproject into each image<br>
**r**: reset gui to the first frame and remove Animator restrictions<br>
**u**: reset the current frame to the initial marker positions<br>
**z**: Toggle zoom state<br>
**p**: Show 3d animation plot of the triangulated points.<br>
**backspace**: reset currently held node (first click and hold, then backspace to delete)<br>
**pageup**: Set the selectedNode to the first node<br>
**tab**: shift the selected node by 1<br>
**shift+tab**: shift the selected node by -1<br>
**h**: print help messages for all Animators<br>
**shift+s**: Save the data to a .mat file

Written by Diego Aldarondo (2019)

Some code adapted from https://github.com/talmo/leap
