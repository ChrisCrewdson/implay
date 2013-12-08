/***************************************************************************
 * IMPLAY
 * Andrew Lim & Bunnie Curtis
 * 2013-12-07
 *
 * Device Code
 *
 ***************************************************************************/

/***************************************************************************
 * CONFIG
 ***************************************************************************/

//Setup your piezo pins here
piezo_pins <- [hardware.pin8, hardware.pin7, hardware.pin5, hardware.pin2];

//Playback LED
led <- hardware.pin9;

/***************************************************************************
 * INCLUDES
 ***************************************************************************/

    /***************************************************************************
     * Tone/Song Class
     * https://github.com/electricimp/reference/blob/master/hardware/tone/tone.hardware.nut
     ***************************************************************************/

        class timer {

            cancelled = false;
            paused = false;
            running = false;
            callback = null;
            interval = 0;
            params = null;
            send_self = false;
            static timers = [];

            // -------------------------------------------------------------------------
            constructor(_params = null, _send_self = false) {
                params = _params;
                send_self = _send_self;
                timers.push(this); // Prevents scoping death
            }

            // -------------------------------------------------------------------------
            function _cleanup() {
                foreach (k,v in timers) {
                    if (v == this) return timers.remove(k);
                }
            }
            
            // -------------------------------------------------------------------------
            function update(_params) {
                params = _params;
                return this;
            }

            // -------------------------------------------------------------------------
            function set(_duration, _callback) {
                assert(running == false);
                callback = _callback;
                running = true;
                imp.wakeup(_duration, alarm.bindenv(this))
                return this;
            }

            // -------------------------------------------------------------------------
            function repeat(_interval, _callback) {
                assert(running == false);
                interval = _interval;
                return set(_interval, _callback);
            }

            // -------------------------------------------------------------------------
            function cancel() {
                cancelled = true;
                return this;
            }

            // -------------------------------------------------------------------------
            function pause() {
                paused = true;
                return this;
            }

            // -------------------------------------------------------------------------
            function unpause() {
                paused = false;
                return this;
            }

            // -------------------------------------------------------------------------
            function alarm() {
                if (interval > 0 && !cancelled) {
                    imp.wakeup(interval, alarm.bindenv(this))
                } else {
                    running = false;
                    _cleanup();
                }

                if (callback && !cancelled && !paused) {
                    if (!send_self && params == null) {
                        callback();
                    } else if (send_self && params == null) {
                        callback(this);
                    } else if (!send_self && params != null) {
                        callback(params);
                    } else  if (send_self && params != null) {
                        callback(this, params);
                    }
                }
            }
        }

        class Tone {
            pin = null;
            playing = null;
            wakeup = null;

            constructor(_pin) {
                this.pin = _pin;
                this.playing = false;
            }
            
            function isPlaying() {
                return playing;
            }
            
            function play(freq, duration = null) {
                if (playing) stop();
                
                //AL: Add LED pin writing
                led.write(0);

                freq *= 1.0;
                pin.configure(PWM_OUT, 1.0/freq, 1.0);
                pin.write(0.5);
                playing = true;
                
                if (duration != null) {
                    wakeup = timer().set(duration, stop.bindenv(this));
                }
            }
            
            function stop() {
                if (wakeup != null){
                    wakeup.cancel();
                    wakeup = null;
                } 
                
                //AL: Add LED pin writing
                led.write(1);
                
                pin.write(0.0);
                playing = false;
            }
        }

        class Song {
            tone = null;
            song = null;
            
            currentNote = null;
            
            wakeup = null;
            
            constructor(_tone, _song) {
                this.tone = _tone;
                this.song = _song;

                this.currentNote = 0;
            }
            
            // Plays the song frmo the start
            function Restart() {
                Stop();
                Play();
            }
            
            // Plays song from current position
            function Play() {
                if (currentNote < song.len()) {
                    tone.play(song[currentNote].n, 1.0/song[currentNote].d);
                    wakeup = timer().set(1.0/song[currentNote].d + 0.01, Play.bindenv(this));
                    currentNote++;
                }
            }
            
            // Stops playing, and saves position
            function Pause() {
                tone.stop();
                if (wakeup != null) {
                    wakeup.cancel();
                    wakeup = null;
                }
            }
            
            // Stops playing and resets position
            function Stop() {
                Pause();
                currentNote = 0;
            }
        }

/***************************************************************************
 * IMPLAY Code
 ***************************************************************************/

NOTES <- [33,35,37,39,41,44,46,49,52,55,58,62,65,69,73,78,82,87,93,98,104,110,117,123,131,139,147,156,165,175,185,196,208,220,233,247,262,277,294,311,330,349,370,392,415,440,466,494,523,554,587,622,659,698,740,784,831,880,932,988,1047,1109,1175,1245,1319,1397,1480,1568,1661,1760,1865,1976,2093,2217,2349,2489,2637,2794,2960,3136,3322,3520,3729,3951,4186,4435,4699,4978,0];
NOTE_MAP <- { c = 0, cs = 1, d = 2, ds = 3, e = 4, f = 5, fs = 6, g = 7, gs = 8, a = 9, as = 10, b = 11 };

led.configure(DIGITAL_OUT_OD);
led.write(1);

function setupPiezo() {
    piezo <- [];
    for (local i = 0; i < piezo_pins.len(); i += 1) { 
        piezo.push(Tone(piezo_pins[i]));
    }
    server.log("Piezo channels: "+piezo.len());
}

setupPiezo();

//Very rudimentary MML parsing
function createSongFromString(songtext) {
    songtext = songtext.tolower();
    local songArray = [];
    local index = 0;
    local songlen = songtext.len();
    local octave = 5;
    local dur = 4;
    local ignore = 0;
    for (local i = 0; i < songtext.len(); i += 1) {
        
        local cmd = songtext[i]
        local cmdname = cmd.tochar();
        local notenum = 88;
       
       //strip out hash tags  
        if (cmdname == "#") {
            ignore = 1;
        }
        
        if (ignore == 0) {
            //note commands, abcdefg/
            if ((cmd >= 97 && cmd <= 103) || cmdname == "/") {
                if (cmdname != "/") {        
                    notenum = NOTE_MAP[cmdname] + (octave*12);
                    if (i < songtext.len() - 1) { 
                        local sharp = songtext[i+1].tochar();
                        //sharp handling, s or +
                        if (sharp == "s" || sharp == "+") {
                            notenum += 1;
                            i += 1;
                        }
                    }            
                }
                
                songArray.push({n = NOTES[notenum], d = dur});
            }
            //octave down
            else if(cmdname == "<") {
                octave -= 1;
            }
            //octave up
            else if(cmdname == ">") {
                octave += 1;
            }
            //set octave
            else if(cmdname == "o") {
                //rudimentary digit parsing!!
                if (i < songtext.len() - 1) { 
                    local digit = songtext[i+1];
                    if (digit >= 48 && digit <= 57) {
                        octave = digit.tochar().tointeger();
                        i += 1;
                    }
                }     
            }
            //set length (duration)
            else if(cmdname == "l") {
                local newlen = ""
                //rudimentary digit parsing!!
                if (i < songtext.len() - 1) { 
                    local digit = songtext[i+1];
                    if (digit >= 48 && digit <= 57) {
                        newlen += digit.tochar();
                        i += 1;
                        if (i < songtext.len() - 1) { 
                            local digit2 = songtext[i+1];
                            if (digit2 >= 48 && digit2 <= 57) {
                                newlen += digit2.tochar();
                                i += 1;
                            }
                        }
                    }
                }
                if (newlen.len() > 0) {
                    dur = newlen.tointeger();
                }
            }
            //whitespace ends hashtag
            else if(cmdname == " " || cmdname == "\n" || cmdname == "\r" || cmdname == "\t") {                
                ignore = 0;
            }
            else {       
                server.log("ERROR PARSING SONG invalid cmd: "+cmdname);
                return [];
            }
        }
        //whitespace ends hashtag
        else if(cmdname == " " || cmdname == "\n" || cmdname == "\r" || cmdname == "\t") {                
            ignore = 0;
        }
        
    }

    return songArray;
    
}

//device side song handler
function playSong(state) {
    server.log("device received song: "+state);
    local songtexts = split(state,"|");
    local channels = songtexts.len();
    server.log("song contains channels: "+channels);
    if (channels > piezo.len()) {
        channels = piezo.len();
    }
    server.log("parsing only channels: "+channels);
    local songs = [];
    for (local i=0; i < channels; i+= 1) {
        server.log("Parsing channel "+i);
        server.log(imp.getmemoryfree());
        local songArray = createSongFromString(songtexts[i]);
        songs.push(Song(piezo[i], songArray));
    }
    for (local i=0; i < channels; i+= 1) {
        songs[i].Play();
    }
}

agent.on("play",playSong);