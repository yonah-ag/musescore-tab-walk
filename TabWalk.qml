/* MuseScore Plugin: Tab Walk
 *
 * Copyright © 2023 yonah_ag
 *
 *  This program is free software; you can redistribute it or modify it under
 *  the terms of the GNU General Public License version 3 as published by the
 *  Free Software Foundation and appearing in the accompanying LICENSE file.
 *
 *  Description
 *  -----------
 *  Walk through plugin elements in a TAB score
 *  Output to file TabWalk.csv in user temp folder
 *
 *  Releases
 *  --------
 *  1.0.0 : 02 Mar 2023 - Initial Release
 *  1.1.0 : 04 Mar 2023 - Use pitch note name rather than TPC
 *  1.1.1 : 25 Mar 2023 - Add tuplet detection
 *  1.1.2 : 03 Apr 2023 - Detect harmony symbols
 *  1.1.3 : 05 Apr 2023 - Add Part count and Track data
 */

import QtQuick 2.2
import FileIO 3.0
import QtQuick.Dialogs 1.1
import MuseScore 3.0

MuseScore {
   version: "1.1.3"
   description: "Walks through plugin elements in a TAB score, saving details to TabWalk.csv"
   menuPath: "Plugins.Tab Walk"
   requiresScore: true;

   property var noteName : ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
   property var tsts : "" // result status
   property var tout : "" // text output

   FileIO {
      id: outfile
      source: tempPath() + "/TabWalk.csv"
      onError: console.log("FileIO Error")
   }

   onRun: {

      var segType = Object.freeze({
         0: "Invalid",
         1: "BeginBarLine",
         2: "HeaderClef",
         4: "KeySig",
         8: "Ambitus",
         16: "TimeSig",
         32: "StartRepeatBarLine",
         64: "Clef",
         128: "BarLine",
         256: "Breath",
         512: "ChordRest",
        1024: "EndBarLine",
        2048: "KeySigAnnounce",
        4096: "TimeSigAnnounce"
      });
      curScore.createPlayEvents(); // populate play events with info

      tout = "\nTitle:," + curScore.title + "\nComposer:," + curScore.composer;
      tout += "\n\nParts:  " + curScore.parts.length;
      tout += ",Staves:  " + curScore.nstaves;
      tout += ",Tracks:  " + curScore.ntracks;
      tout += ",Measures:  " + curScore.nmeasures;
      tout += ",Duration:  " + curScore.duration + " s ";
      tout += "\n\nMeasure,Segment,Element,Element,Property:,  Value  ,Property:,  Value  ,Property:,  Value  ,Property:,  Value  ,Property:,  Value  ,Property:,  Value  ,Property:,  Value  ,Property:,  Value  \n";

      var mez = curScore.firstMeasure;
      var tock = 0; // actual note stop tick (used for tuplets)
      var nMez = 1;
      while (mez) {
         var seg = mez.firstSegment;
         var mezInfo = "\n" + nMez;
         for (var ee in mez.elements) {
             mezInfo += "," + seg.tick + "," + mez.elements[ee].type + ": " + mez.elements[ee].name + "\n";
         }
         while (seg) {
            var segInfo = "," + seg.tick + "," + segType[Number(seg.segmentType)];
            if (seg.annotations && seg.annotations.length) {
               for (var aa in seg.annotations) {
                  var anno  = seg.annotations[aa];
                  segInfo += "\n,,," + anno.type + ": Annotation," + anno.name + ":";
                  if (anno.type == 42) { // STAFF TEXT
                     segInfo += ',"""' + anno.text.substring(0,8) + '""",Align:,' + anno.align;
                     segInfo += ",position:," + anno.placement + ",posX:," + anno.posX.toFixed(2) + ",posY:," + anno.posY.toFixed(2);
                  }
                  else if (anno.type == 41) {  // TEMPO
                     segInfo += "," + (60*anno.tempo) + " bpm";
                  }
                  else if (anno.type == 47) { // HARMONY
                     segInfo += "," + anno.text;
                  }
               }
            }
            for (var vv = 0; vv < curScore.ntracks; ++vv) {
               var elm = seg.elementAt(vv);
               if (elm) {
                  segInfo += "\n,,," + elm.type + ": " + elm.name;
                  if (elm.type == 93) { // CHORD
                     segInfo += ",Duration:," + elm.duration.numerator + "|" + elm.duration.denominator + ",Ticks:," + elm.duration.ticks;
                     segInfo += ",Grace notes:," + elm.graceNotes.length;
                     if (elm.tuplet != null) {
                        segInfo += "\n,,,,Tuplet:," + elm.tuplet.actualNotes + "|" + elm.tuplet.normalNotes;
                        segInfo += ",Tuplen:," + Math.floor(elm.duration.ticks * elm.tuplet.normalNotes / elm.tuplet.actualNotes);
                     }
                     segInfo += "\n,,,,Notes:," + elm.notes.length;
                     for (var nn in elm.notes) {
                        var note = elm.notes[nn];
                        var pitch = note.pitch;
                        var tnote = pitch % 12;
                        var name = noteName[tnote];
                        var ynTiB = ""; var ynTiF = ""; var ynPla = "";
                        var ynVis = ""; var ynGho = ""; var ynSml = "";
                        (note.tieBack != null) ? ynTiB="Y" : ynTiB="N";
                        (note.tieForward != null) ? ynTiF="Y" : ynTiF="N";
                        (note.play) ? ynPla="Y" : ynPla="N";
                        (note.visible) ? ynVis="Y" : ynVis="N";
                        (note.ghost) ? ynGho="Y" : ynGho="N";
                        (note.small) ? ynSml="Y" : ynSml="N";
                        segInfo += "\n,,,,,,String:," + (1+note.string) + ",Fret:," + note.fret + ",Note:," + note.pitch + " " + name + " ";
                        segInfo += ",Voice:," + (1+note.voice) + " ,tieBack:," + ynTiB + ",tieForward:," + ynTiF + ",Colour:," + note.color;
                        segInfo += "\n,,,,,,Play:," + ynPla + ",Visible:," + ynVis + ",Ghost:," + ynGho + ",Track:," + vv + ",Small:," + ynSml;
                        segInfo += ",vType:," + note.veloType + ",vOffset:," + note.veloOffset;
                        for (var mm in note.elements) {
                           segInfo += "\n,,,,,," + note.elements[mm].name + ":";
                        }
                        segInfo += "\n,,,,,,ontime:," + note.playEvents[0].ontime + ",len:," + note.playEvents[0].len + ",offtime:," + note.playEvents[0].offtime;
                     }
                  }
                  else if (elm.type == 25) { // REST
                     segInfo += "," + elm.type + ": Duration:," + elm.duration.numerator + "|" + elm.duration.denominator + ",Ticks:," + elm.duration.ticks;
                  }
                  else if (elm.type == Element.TIMESIG) {
                     segInfo += "," + mez.timesigActual.ticks + "," + mez.timesigActual.numerator + "|" + mez.timesigActual.denominator;
                  }
               }
            }
            mezInfo += segInfo + "\n";
            seg = seg.nextInMeasure;
         }
         tout += mezInfo;
         mez = mez.nextMeasure;
         ++nMez;
      }

      var rc = outfile.write(tout);
      if (rc){
         tsts = "Finished: file saved";
         tout = "Output file:\n"+outfile.source;
      }
      else {
         tsts = "Error: something went wrong";
         tout = "File cannot be written";
      }
      finiRun.open()
   }

   MessageDialog { id: finiRun
      standardButtons: StandardButton.Ok
      title: "Tab Walk"
      text: tsts
      detailedText: tout
      onAccepted: {}
   }
}