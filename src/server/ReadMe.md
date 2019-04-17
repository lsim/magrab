# Magrab

Margrethe's image grabbing stop motion play house.

Built with node.js backend and elm frontend.

#### TODO

When the frontend changes the state, the change is fired at the backend, which pushes the updated state to the frontend, when it has been persisted. It should be reasonably fast because only image meta data is communicated thus.

*server*
- Use nedb to store project data
- Use disk to store image data
- Generate image file names
  - perhaps with project id in the name
  - when deleting a scene, the associated images should be deleted too DONE
  - when deleting a project, the project id in the file name may help prevent leaking image files.
- Find tech for animating jpegs into a gif
  - get-pixels for getting jpg pixels
  - gif-encoder for encoding the gif

*client*
- use fomantic ui styling (Seems a bit of overkill for such a small app)
- leafing through scenes DONE
- leafing through images DONE
- project crud 
- scene crud DONE
- change scene order DONE
- change image order 
- view finder (http://camera/video/mjpg.cgi in an iframe? How about auth?)
- Undo/redo would be cool - there's a lib for that

