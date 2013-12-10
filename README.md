# IMPLAY

IMPLAY lets you send 

## Installation

1. Copy `implay.agent.nut` to the agent.
2. Setup variables

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

3. Copy `implay.device.nut` on the device.
4. Setup the pin variables to match your setup.
   You can change the number of piezos by adding or removing pins to the array.

    piezo_pins <- [hardware.pin8, hardware.pin7, hardware.pin5, hardware.pin2];
    led <- hardware.pin9;

5. Build & Run!

## Usage

You can send a song in two ways:

1. Go to your agent's URL and write a song using the text box and `Play`
2. Tweet a song using the hashtag you provided in `_SEARCH_TERM`,
   all @mentions and #tags will be stripped from input.

## Song storage on Firebase

You can set predefined songs in firebase.  A sample JSON dump is in 
`firebase-samples.json` which you can import into Firebase using the
`Import JSON` function.

To playback a song by name simply write the song's name in text.
Only single word alphanumeric and not all special characters are supported
as part of the song's name.

## Music Syntax

* Notes are any letter from a to g `abcdefg`
* To make a note sharp (+1 half-step or semitone) add an `s` (eg C# is `cs`)
* `l<length>` sets note length division. Defaults to 8
  `l4` is quarter note, `l8` is eigth note, `l16` sixteenth, etc.
* `o<octave>` sets octave (1 to 7). Defaults to 5
* `>` increases current octave by 1
* `<` decreases current octave by 1
* `t<tempo>` sets tempo in BPM (32 to 255). Defaults to 120
* `m<gap>` sets gap length before next note as `<gap>` * 0.01ms.
  Larger values give shorter stacatto notes. Defaults to 0
* `p<duty>` sets pulse duty to `<duty>` * 0.1.
  `p5` is a square wave. Defaults to 5
