import java.util.List;
import org.c3cavite.core.domain.AgeTier;
import org.c3cavite.core.domain.AssignmentResult;
import org.c3cavite.core.domain.AssignmentState;
import org.c3cavite.core.domain.Facilitator;
import org.c3cavite.core.domain.Gender;
import org.c3cavite.core.domain.GenderMode;
import org.c3cavite.core.domain.Participant;
import org.c3cavite.core.domain.Role;
import org.c3cavite.core.domain.SessionConfig;
import org.c3cavite.core.service.GroupAssignmentService;

public final class ConsumerMain {
  private ConsumerMain() {}

  public static void main(String[] args) {
    SessionConfig config =
        SessionConfig.create(GenderMode.MIXED, 5, 8, List.of(AgeTier.TEENS), false);
    List<Participant> participants =
        List.of(
            new Participant("P1", 14, Gender.MALE, null),
            new Participant("P2", 14, Gender.FEMALE, null));
    List<Facilitator> facilitators =
        List.of(new Facilitator("L1", Role.LEADER, Gender.MALE, List.of(AgeTier.TEENS)));

    AssignmentResult result =
        new GroupAssignmentService().assign(config, participants, facilitators);
    if (result.getState() != AssignmentState.FINAL
        || result.getTotalGroups() != 1
        || result.getTotalAssignedParticipants() != 2
        || !"L1".equals(result.getGroups().get(0).getLeader().getName())) {
      throw new AssertionError("Expected one final group with two participants and leader L1");
    }
    System.out.println("Standalone Maven consumer passed");
  }
}
