module.exports = {
  port: 3000,
  imagePath: process.env.IMAGE_PATH || 'images',
  projectsDbFile: process.env.DB_FILE_PATH || 'magrab-projects.db',
  gifPath: process.env.VIDEO_PATH || 'gifs',
};
