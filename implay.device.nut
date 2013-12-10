/***************************************************************************
 * IMPLAY
 * Andrew Lim & Bunnie Curtis
 * 2013-12-07
 *
 * Device Code
 *
 ***************************************************************************/

piezo_pins <- [hardware.pin8, hardware.pin7, hardware.pin5, hardware.pin2];
led <- hardware.pin9;

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
    channel = null;

    constructor(_pin,_channel) {
        this.pin = _pin;
        this.channel = _channel;
        this.playing = false;
    }
    
    function isPlaying() {
        return playing;
    }
    
    function play(freq, duration = null, duty = 0.5) {
        if (playing) stop();
        
        //AL: Add LED pin writing
        led.write(0);

        freq *= 1.0;
        if (freq > 0.0) {
            pin.configure(PWM_OUT, 1.0/freq, 1.0);
            pin.write(duty);
        }
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
    flush = null;
    gap = null
    currentIndex = null;
    duty = null;
    tempo = null;
    wakeup = null;
    
    constructor(_tone, _song) {
        this.tone = _tone;
        this.song = _song;
        this.flush = false;
        this.gap = 0.00;
        this.duty = 0.5;
        this.tempo = 120.0 / 60.0;
        this.currentIndex = 0;
    }
    
    // Plays the song frmo the start
    function Restart() {
        Stop();
        Play();
    }
    
    // Plays song from current position
    // AL: use blobs and callback on finish
    function Play(_flush) {
        this.flush = _flush;
        Next();        
    }
    function EndSong() {
        if (this.flush) {
            server.log("Flushing song");
            song.flush();
        }      
    }
    function Next() {
        if (currentIndex < song.len()) {
            local n = 0
            local d = 0
            while (true) {
                n = song[currentIndex];
                d = song[currentIndex+1];
                currentIndex+=2;
                if (n < 128) { //note command
                    break;
                }
                else if (n == 255) { //set gap time
                    gap = 0.01 * d.tofloat();
                }
                else if (n == 254) { //set duty cycle
                    duty = 0.1 * d.tofloat();
                }
                else if (n == 253) { //set tempo
                    if (d < 32) d = 32;
                    tempo =  (60.0 / d.tofloat()) * 4.0;
                }
                else { //invalid
                    EndSong();
                    break;
                }
            }
            if (d > 0) {
                local f = NOTES[n];
                if (f > 0) {
                    tone.play(NOTES[n], ((tempo/d) - gap), duty);
                }
                wakeup = timer().set(tempo/d, Next.bindenv(this));
            }
            else {  //zero duration is end of song
                EndSong();
            }
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
        currentIndex = 0;
    }
    
    //AL: Flush blobs
    function Flush() {
        this.song.flush();
    }
}

/***************************************************************************
 * END Tone/Song Class
 ***************************************************************************/

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
        piezo.push(Tone(piezo_pins[i],i));
    }
    server.log("Piezo channels: "+piezo.len());
}

setupPiezo();

//Very rudimentary MML parsing
function createSongFromString(songtext) {
    songtext = songtext.tolower();
    local songblob = blob(128);
    local index = 0;
    local songlen = songtext.len();
    local octave = 5;
    local dur = 8;
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
                songblob.writen(notenum, 'b'); //note command
                songblob.writen(dur, 'b'); //note duration
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
            //set duty
            else if(cmdname == "p") {
                //rudimentary digit parsing!!
                if (i < songtext.len() - 1) { 
                    local digit = songtext[i+1];
                    if (digit >= 48 && digit <= 57) {
                        songblob.writen(254,'b') //duty change command
                        songblob.writen(digit.tochar().tointeger(), 'b')
                        i += 1;
                    }
                }     
            }
            //set gap time
            else if(cmdname == "m") {
                local newgap = ""
                //rudimentary digit parsing!!
                if (i < songtext.len() - 1) { 
                    local digit = songtext[i+1];
                    if (digit >= 48 && digit <= 57) {
                        newgap += digit.tochar();
                        i += 1;
                        if (i < songtext.len() - 1) { 
                            local digit2 = songtext[i+1];
                            if (digit2 >= 48 && digit2 <= 57) {
                                newgap += digit2.tochar();
                                i += 1;
                            }
                        }
                    }
                }
                if (newgap.len() > 0) {
                    songblob.writen(255,'b') //gap change command
                    songblob.writen(newgap.tointeger(), 'b')
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
            else if(cmdname == "t") {
                local newtempo = ""
                //rudimentary digit parsing!!
                if (i < songtext.len() - 1) { 
                    local digit = songtext[i+1];
                    if (digit >= 48 && digit <= 57) {
                        newtempo += digit.tochar();
                        i += 1;
                        if (i < songtext.len() - 1) { 
                            local digit2 = songtext[i+1];
                            if (digit2 >= 48 && digit2 <= 57) {
                                newtempo += digit2.tochar();
                                i += 1;
                                if (i < songtext.len() - 1) { 
                                    local digit3 = songtext[i+1];
                                    if (digit3 >= 48 && digit3 <= 57) {
                                        newtempo += digit3.tochar();
                                        i += 1;
                                    }
                                }
                            }
                        }
                    }
                }
                if (newtempo.len() > 0) {
                    songblob.writen(253,'b') //tempo command
                    songblob.writen(newtempo.tointeger(), 'b')
                }
            }            //whitespace ends hashtag
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
    songblob.writen(0,'b'); //end of track
    songblob.writen(0,'b');
    return songblob;
    
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
        local songblob = createSongFromString(songtexts[i]);
        songs.push(Song(piezo[i], songblob));
    }
    for (local i=0; i < channels; i+= 1) {
        songs[i].Play(true);        
    }
}

agent.on("play",playSong);