// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// ignore_for_file: avoid_print

import 'package:aud_midi_rtp/aud_midi_rtp.dart';
import 'package:aud_midi_standard/aud_midi_standard.dart';

void main() {
  // A sender and a receiver with the AppleMIDI configuration
  final sender = MidiRtpSender(ssrc: 0x1234, sequenceNumber: 100);
  final receiver = MidiRtpReceiver(
    onIssue: (kind, message) => print('${kind.name}: $message'),
  );

  // Three packets: a note, a control change and the end of the note
  final packets = [
    for (final (message, ms) in [
      (const MidiNoteOn(channel: 0, note: 60, velocity: 90), 0),
      (const MidiControlChange(channel: 0, controller: 7, value: 100), 10),
      (const MidiNoteOff(channel: 0, note: 60), 20),
    ])
      ...sender.send([(message: message, time: MidiTime(ms * 1000))]),
  ];

  // The network loses the second packet; the recovery journal of the
  // third one repairs the control change before the third's own command
  for (final packet in [packets[0], packets[2]]) {
    for (final (:message, :time) in receiver.receive(packet.toBytes())) {
      print('$time $message');
    }
  }

  // The receiver's feedback lets the sender trim its history
  sender.acknowledge(receiver.feedbackSequenceNumber!);
}
