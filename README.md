# Label3D

Label3D is a GUI for manual labeling of 3D keypoints in multiple cameras.

## Features
<ol>
<li>Simultaneous viewing of any number of camera views</li>
<li>Multiview triangulation of 3D keypoints</li>
<li>Point-and-click and draggable gestures to label keypoints</li>
<li>Zooming, panning, and other default Matlab gestures</li>
<li>Integration with `Animator` classes</li>
</ol>

## Usage

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
**r**: reset gui to the first frame and remove `Animator` restrictions<br>
**u**: reset the current frame to the initial marker positions<br>
**z**: zoom all images out to full size<br>
**tab**: shift the selected node by 1<br>
**ctrl+tab** or backspace: shift the selected node by -1<br>
**shift+s**: save data to a `.mat` file<br>
**h**: print help messages for all `Animators`

Written by Diego Aldarondo (2019)

Some code adapted from https://github.com/talmo/leap
