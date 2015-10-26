# MeteorEngine
A custom graphics engine for XNA

![Deferred and Light Pre-Pass Rendering](https://electronicmeteor.files.wordpress.com/2013/02/poisson-3.jpg?w=788)

###Overview of Meteor Rendering Engine

The Meteor rendering engine is developed in C# with XNA 4.0, and provides various rendering setups in which to display 3D scenes quickly and easily. The example setups provided are deferred rendering and light pre-pass rendering, but you can just as well use your own. 

Rendering setups, or "render profiles" are broken down into steps, which are presented as components which can be re-arranged and combined in several ways to provide the render output you need. You can also extend from existing components or make your own for your own custom renderer. It is possible to load several different profiles and even change them on the fly to fit the current situation, if rendering requirements change.

You can find some details of the engine process in my blog, Electronic Meteor.

This engine is very much a work-in-progress, so there is no release candidate and many refinements to some of the core files are still underway. For now, only the bare engine code and sample components are available. This can be compiled as a library which you can use for your existing program.

You may need the library produced by the XNA Skinned Animation sample if you want to support that in the engine. I will soon provide sample code for a working application that uses it. The included fonts use the Nuclex Spritefont processor, but if you don't have it/don't want to use it, you can simply use the built-in Spritefont processor.

Here are some of the features all created with the sample renderers.

Deferred and Light Pre-Pass Rendering

Terrain rendering with geo-mipmapping (work in progress)

![Terrain rendering with geo-mipmapping](http://electronicmeteor.files.wordpress.com/2013/02/terrain3.jpg)

Gamma Correction

![Gamma correction](http://electronicmeteor.files.wordpress.com/2012/08/features-gamma.jpg?w=604&h=339)

Post-Processing Effects

![Post-processing effects](http://electronicmeteor.files.wordpress.com/2012/08/features-bloom.jpg?w=604&h=339)

