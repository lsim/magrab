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
  - when deleting a scene, the associated images should be deleted too
  - when deleting a project, the project id in the file name may help prevent leaking image files.
- Find tech for animating jpegs into a gif
  - get-pixels for getting jpg pixels
  - gif-encoder for encoding the gif

*client*
- use fomantic ui styling
- leafing through scenes
- leafing through images
- project crud
- scene crud
- change scene order
- change image order
- 

