# aud_midi_rtp

English | [Deutsch](README.de.md)

RFC 6295 RTP-MIDI in Dart: payload format and complete recovery journal, no
sockets. It holds the sender and the receiver as a codec only, without
`dart:io`.

Part of the aud_midi family, see [aud_midi](https://github.com/audmidi/aud_midi).

## Motivation

RTP-MIDI should be usable as a plain Dart package by any project — a
sequencer, a test tool or a converter — without native code and without a
network stack of its own: the codec turns messages into packets and packets
into messages, and the recovery journal repairs what the network lost. The
package aims for:

- RTP-MIDI payload and MIDI command section
- Complete recovery journal, all channel and system chapters
- Sender policies and receiver repair
- Session configuration per Appendix C
- In-memory lossy channel for tests

## Installation

```bash
dart pub add aud_midi_rtp
```

## Usage

Send three packets, lose one on the way and let the recovery journal of
the next packet repair it:

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

It prints:

```text
0 MidiNoteOn(channel: 0, note: 60, velocity: 90)
networkLoss: Lost 1 packet(s) before 102, recovered from the journal
20000 MidiControlChange(channel: 0, controller: 7, value: 100)
20000 MidiNoteOff(channel: 0, note: 60, velocity: 64)
```

## Limitations

- Codec only: the package opens no socket and uses no `dart:io`. Session
  setup, discovery and transport belong to the caller.
- Open: tests against packet captures of Apple's driver, together with
  `aud_midi_network`.

## Documentation

- [Plan of the aud_midi family](https://github.com/audmidi/aud_midi_pm/blob/main/doc/2026-Q4/tickets/2026-10-06-aud_midi_01-initial-midi-implementation.md)
- [Guides](doc/guides/)

## How it works

- RTP header, MIDI command section (B, J, Z, P, LEN), delta times, running status, SysEx segmentation and cancel
- Complete recovery journal: channel chapters P, C, M, W, N, E, T, A, system chapters D, V, Q, F, X, enhanced Chapter C
- `MidiRtpSender`: session history, closed-loop (default), open-loop and anchor checkpoints, S bits, trimming after feedback
- `MidiRtpReceiver`: sequence tracking, checkpoint validation, per-chapter repair, loss diagnostics and counters
- `MidiRtpSessionConfig`: `fmtp` parameters of Appendix C, AppleMIDI preset
- `MidiRtpLossyChannel`: loss, bursts, reordering and duplication for tests

## Status

Before 1.0 — the API may change between minor versions. The codec is
implemented in full; the tests against captures of Apple's driver are still
open.

## Contributing

See [doc/guides/develop-guide.md](doc/guides/develop-guide.md).

## License

MIT — see [LICENSE](LICENSE).
