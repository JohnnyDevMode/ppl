process.env.NODE_ENV = 'test'
chai = require 'chai'
global.assert = chai.assert
global.expect = chai.expect
global.should = chai.should()
chai.use require 'chai-things'
