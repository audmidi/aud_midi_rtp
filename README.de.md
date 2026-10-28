# aud_midi_rtp

[English](README.md) | Deutsch

RFC 6295 RTP-MIDI in Dart: Payload-Format und vollständiges Recovery
Journal, keine Sockets. Es enthält Sender und Empfänger als reinen Codec,
ohne `dart:io`.

Teil der aud_midi-Familie, siehe [aud_midi](https://github.com/audmidi/aud_midi).

## Motivation

RTP-MIDI soll als reines Dart-Paket in jedem Projekt nutzbar sein — in
einem Sequenzer, einem Testwerkzeug oder einem Konverter — ohne nativen
Code und ohne eigenen Netzwerk-Stack: Der Codec macht aus Nachrichten
Pakete und aus Paketen Nachrichten, und das Recovery Journal repariert, was
das Netzwerk verloren hat. Das Paket zielt auf:

- RTP-MIDI-Payload und MIDI-Command-Section
- Vollständiges Recovery Journal, alle Channel- und System-Chapter
- Sender-Policies und Reparatur beim Empfänger
- Session-Konfiguration nach Appendix C
- In-Memory-Kanal mit Paketverlust für Tests

## Installation

```bash
dart pub add aud_midi_rtp
```

## Verwendung

Drei Pakete senden, eines unterwegs verlieren und es vom Recovery Journal
des nächsten Pakets reparieren lassen:

```dart
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
```

Es gibt aus:

```text
0 MidiNoteOn(channel: 0, note: 60, velocity: 90)
networkLoss: Lost 1 packet(s) before 102, recovered from the journal
20000 MidiControlChange(channel: 0, controller: 7, value: 100)
20000 MidiNoteOff(channel: 0, note: 60, velocity: 64)
```

## Einschränkungen

- Nur Codec: Das Paket öffnet keinen Socket und verwendet kein `dart:io`.
  Session-Aufbau, Discovery und Transport liegen beim Aufrufer.
- Offen: Tests gegen Mitschnitte von Apples Treiber, zusammen mit
  `aud_midi_network`.

## Dokumentation

- [Plan der aud_midi-Familie](https://github.com/audmidi/aud_midi_pm/blob/main/doc/2026-Q4/tickets/2026-10-06-aud_midi_01-initial-midi-implementation.md)
- [Guides](doc/guides/)

## Funktionsweise

- RTP-Header, MIDI-Command-Section (B, J, Z, P, LEN), Delta Times, Running Status, SysEx-Segmentierung und -Abbruch
- Vollständiges Recovery Journal: Channel-Chapter P, C, M, W, N, E, T, A, System-Chapter D, V, Q, F, X, Enhanced Chapter C
- `MidiRtpSender`: Session-Historie, Checkpoints per Closed Loop (Standard), Open Loop und Anchor, S-Bits, Kürzen nach Feedback
- `MidiRtpReceiver`: Sequenznummern, Checkpoint-Prüfung, Reparatur pro Chapter, Diagnosen und Zähler bei Verlust
- `MidiRtpSessionConfig`: `fmtp`-Parameter nach Appendix C, AppleMIDI-Voreinstellung
- `MidiRtpLossyChannel`: Verlust, Bursts, Umordnung und Duplikate für Tests

## Status

Vor 1.0 — die API kann sich zwischen Minor-Versionen ändern. Der Codec ist
vollständig implementiert; die Tests gegen Mitschnitte von Apples Treiber
stehen noch aus.

## Mitwirken

Siehe [doc/guides/develop-guide.md](doc/guides/develop-guide.md).

## Lizenz

MIT — siehe [LICENSE](LICENSE).
