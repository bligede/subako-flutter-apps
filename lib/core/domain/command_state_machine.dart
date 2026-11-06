import '../../shared/models/enums.dart';

/// Aturan transisi command aktuator.
///
/// Prinsip: ACK bukan bukti gerakan fisik. `EXECUTED` hanya boleh dicapai dari
/// `ACKNOWLEDGED` setelah perangkat melaporkan feedback penyelesaian.
class CommandStateMachine {
  const CommandStateMachine._();

  static const Map<CommandStatus, Set<CommandStatus>> _transitions =
      <CommandStatus, Set<CommandStatus>>{
        CommandStatus.created: <CommandStatus>{
          CommandStatus.validating,
          CommandStatus.cancelled,
          CommandStatus.rejected,
        },
        CommandStatus.validating: <CommandStatus>{
          CommandStatus.queued,
          CommandStatus.rejected,
          CommandStatus.failed,
        },
        CommandStatus.queued: <CommandStatus>{
          CommandStatus.sent,
          CommandStatus.expired,
          CommandStatus.cancelled,
          CommandStatus.failed,
        },
        CommandStatus.sent: <CommandStatus>{
          CommandStatus.acknowledged,
          CommandStatus.timedOut,
          CommandStatus.failed,
        },
        CommandStatus.acknowledged: <CommandStatus>{
          CommandStatus.executed,
          CommandStatus.failed,
          CommandStatus.timedOut,
        },
      };

  static bool canTransition(CommandStatus from, CommandStatus to) {
    if (from.isTerminal) {
      return false;
    }
    return _transitions[from]?.contains(to) ?? false;
  }

  /// Menerapkan transisi; mengembalikan status baru atau melempar error.
  static CommandStatus transition(CommandStatus from, CommandStatus to) {
    if (!canTransition(from, to)) {
      throw StateError(
        'Transisi command tidak sah: ${from.label} -> ${to.label}',
      );
    }
    return to;
  }

  static bool isAckButNotExecuted(CommandStatus status) =>
      status == CommandStatus.acknowledged;
}
