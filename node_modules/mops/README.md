![mops](https://github.com/Katochimoto/mops/raw/master/pic.jpg)

The operation queue.

[![Build Status][build]][build-link] [![NPM version][version]][version-link] [![Dependency Status][dependency]][dependency-link] [![devDependency Status][dev-dependency]][dev-dependency-link] [![Code Climate][climate]][climate-link] [![Test Coverage][coverage]][coverage-link] [![Inline docs][inch]][inch-link]

```js
var action1 = new mops.Action(function() {
    return Promise.reject(new mops.Error('blablabla'));
});

var action2 = new mops.Action(function() {
    return new mops.Queue(this)
        .then(action1)
        .then(action2)
        .then(action3);
});

var action3 = new mops.Action(function() {
    return new Promise(function(resolve) {
        resolve(
            new mops.Queue(this)
                .then(action1)
                .then(action2)
                .then(action3)
                .start()
        );
    });
});

new mops.Queue(new mops.Context({ /* ... */ }))
    .then(action1, param1, param2)
    .then(action2, action3)
    .catch(action4)
    .always(action5)
    .then(function() {}, function() {})
    .catch(function() {})
    .then(function() {
        return new mops.Queue(this)
            .then(action1)
            .then(action2);
    })
    .start();
```

## Install

```
npm install mops
```
```
bower install mops
```

[![NPM](https://nodei.co/npm/mops.png?downloads=true&stars=true)](https://nodei.co/npm/mops/)
[![NPM](https://nodei.co/npm-dl/mops.png)](https://nodei.co/npm/mops/)

[build]: https://travis-ci.org/Katochimoto/mops.svg?branch=master
[build-link]: https://travis-ci.org/Katochimoto/mops
[version]: https://badge.fury.io/js/mops.svg
[version-link]: http://badge.fury.io/js/mops
[dependency]: https://david-dm.org/Katochimoto/mops.svg
[dependency-link]: https://david-dm.org/Katochimoto/mops
[dev-dependency]: https://david-dm.org/Katochimoto/mops/dev-status.svg
[dev-dependency-link]: https://david-dm.org/Katochimoto/mops#info=devDependencies
[climate]: https://codeclimate.com/github/Katochimoto/mops/badges/gpa.svg
[climate-link]: https://codeclimate.com/github/Katochimoto/mops
[coverage]: https://codeclimate.com/github/Katochimoto/mops/badges/coverage.svg
[coverage-link]: https://codeclimate.com/github/Katochimoto/mops
[inch]: https://inch-ci.org/github/Katochimoto/mops.svg?branch=master
[inch-link]: https://inch-ci.org/github/Katochimoto/mops
