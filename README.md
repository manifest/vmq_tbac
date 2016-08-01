# VerneMQ Topic-Based Access Control (TBAC) Plugin

The plugin for VerneMQ that provides client authorization based on MQTT topic.



### How To Use

The plugin is allowing publication and subscription only to topics that
starts with client's username. For instance, a client with username `user/joe`
could only publish or subscribe to `user/joe/#`. Client's username cannot contain
`#` and `+` characters.



### License

The source code is provided under the terms of [the MIT license][license].

[license]:http://www.opensource.org/licenses/MIT
