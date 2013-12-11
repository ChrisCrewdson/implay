# IMPLAY

IMPLAY lets you send music to an array of piezo speakers over the internet
using the [Electric Imp](http://electricimp.com).  It was created over the
Electric Imp Hackathon on December 7th, 2013 by Andrew Lim & Bunnie Curtis
from [IFTTT](http://ifttt.com)

Songs can be stored on [Firebase](https://www.firebase.com).

## Installation

* Copy `implay.agent.nut` to the agent.
* Setup variables

```
    //Hashtag to play on
    _SEARCH_TERM <- "#implay";
    

    //Firebase Auth
    const FIREBASE_URL = "https://xxxxxx.firebaseio.com/"
    const FIREBASE_AUTH = ""


    //Twitter Auth
    _CONSUMER_KEY <- "";
    _CONSUMER_SECRET <- "";
    _ACCESS_TOKEN <- "";
    _ACCESS_SECRET <- "";
```

* Copy `implay.device.nut` on the device.
* Setup the pin variables to match your setup.
   You can change the number of piezos by adding or removing pins to the array.

```
    piezo_pins <- [hardware.pin8, hardware.pin7, hardware.pin5, hardware.pin2];
    led <- hardware.pin9;
```


* Build & Run!

## Usage

You can send a song in two ways:

* Go to your agent's URL and write a song using the text box and `Play`
* Tweet a song using the hashtag you provided in `_SEARCH_TERM`,
   all @mentions and #tags will be stripped from input.

## Song storage on Firebase

You can set predefined songs in Firebase.  A sample JSON dump is in 
`firebase-samples.json` which you can import into Firebase using the
`Import JSON` function.

To playback a song by name simply write the song's name in text.
Only single word alphanumeric and not all special characters are supported
as part of the song's name.

## Music Syntax

The syntax is a very simplified derivative of [MML](http://en.wikipedia.org/wiki/Music_Macro_Language).

### Basic Commands

* Notes are any letter from a to g `abcdefg`
* To make a note sharp (+1 half-step or semitone) add an `s` (eg C# is `cs`)
* `/` rest note
* `l<length>` sets note length division. Defaults to 8
  `l4` is quarter note, `l8` is eigth note, `l16` sixteenth, etc.
* `>` increases current octave by 1
* `<` decreases current octave by 1

#### Example

`l8 edcdeee/ddd/egg/ edcdeeeedded l4 c`

### More commands

* `o<octave>` sets octave (1 to 7). Defaults to 5
* `t<tempo>` sets tempo in BPM (32 to 255). Defaults to 120
* `m<gap>` sets gap length before next note as `<gap>` * 0.01ms.
  Larger values give shorter stacatto notes. Defaults to 0
* `p<duty>` sets pulse duty to `<duty>` * 0.1.
  `p5` is a square wave. Defaults to 5

### Multi-channel

Note that every piezo channel is independent.  Due to the
nature of the code they might drift apart. All commands
(octave, tempo, etc.) are set independently.

* `|` Use this to separate tracks (will send commands to different piezos)

#### Example

Sends a C major chords to four piezos

`c|e|g|>c`
