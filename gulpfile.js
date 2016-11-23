'use strict'
const gulp = require('gulp-help')(require('gulp'))
const coffee = require('gulp-coffee');
const cache = require('gulp-cached')

// Clean

gulp.task('clean:dist', () => {
  const del = require('del')
  delete cache.caches['build:src']
  return del([ 'dist/*' ])
})

gulp.task('clean', [ 'clean:dist' ])

// Build

gulp.task('build:src', () => {
  return gulp.src('src/**/*.coffee')
    .pipe(cache('build:src'))
    .pipe(coffee({bare: true}))
    .pipe(gulp.dest('dist/lib'))
})

gulp.task('build', [ 'build:src' ])

// Dist

gulp.task('dist:package', () => {
  return gulp.src('package.json')
    .pipe(gulp.dest('dist'))
})

gulp.task('dist:readme', () => {
  return gulp.src('README.md')
    .pipe(gulp.dest('dist'))
})

gulp.task('dist:license', () => {
  return gulp.src('LICENSE-MIT')
    .pipe(gulp.dest('dist'))
})

gulp.task('dist', [ 'build', 'dist:package',  'dist:readme',  'dist:license' ])

// Test & Coverage

gulp.task('test:unit', () => {
  require('coffee-script/register')
  const mocha = require('gulp-mocha')
  return gulp.src(['test/**/*.coffee'], { read: false })
    .pipe(mocha({
      require: [
        './test/setup'
      ],
      timeout: 10000
    }))
    .once('error', () => {
        process.exit(1);
    })
    .once('end', () => {
        process.exit();
    })
});

gulp.task('test', [ 'test:unit' ])

gulp.task('default', [ 'help' ])
