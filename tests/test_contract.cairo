// use snforge_std::{
//     ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
//     start_cheat_caller_address, stop_cheat_caller_address,
// };
// use starknet::{ContractAddress, SyscallResultTrait};
// use vote::Vote::{Candidate_Added, Election_Ended, Event, Voted};
// use vote::{IVoteDispatcher, IVoteDispatcherTrait};

// const candidate1_id: u64 = 1;
// const candidate2_id: u64 = 2;
// const candidate3_id: u64 = 3;
// const candidate4_id: u64 = 4;
// const candidate5_id: u64 = 5;

// fn deploy_contract(name: ByteArray) -> (ContractAddress, ContractAddress) {
//     let contract = declare(name).unwrap_syscall().contract_class();
//     let ADMIN: ContractAddress = 'admin'.try_into().unwrap();
//     let constructor_calldata = array![ADMIN.into()];
//     let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap_syscall();
//     (contract_address, ADMIN)
// }

// #[test]
// fn test_initial_election_state_is_false() {
//     let (contract_address, _) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };
//     let hasElection_started = dispatcher.get_election_state();

//     assert(hasElection_started == false, 'Invalid Election state');
// }

// #[test]
// fn test_no_initial_candidate() {
//     let (contract_address, _) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };
//     let candidate_length = dispatcher.get_candidates_length();

//     assert!(candidate_length == 0, "Initial candidates length should be 0");
// }

// #[test]
// fn test_admin_can_add_candidate() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };

//     //ADD CANDIDATE AND ENSURE IT EMITS THE RIGHT EVENT
//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     let mut spy = spy_events();
//     dispatcher.add_candidate(candidate1_id);
//     spy
//         .assert_emitted(
//             @array![
//                 (
//                     dispatcher.contract_address,
//                     Event::Candidate_Added(Candidate_Added { candidate_id: candidate1_id }),
//                 ),
//             ],
//         );
//     let candidate_length = dispatcher.get_candidates_length();

//     //assert candidate Length is now one afting adding first candidate
//     assert!(candidate_length == 1, "Candidate length should now be 1");
// }

// #[test]
// #[should_panic(expected: 'only admin')]
// fn test_only_admin_can_add_candidate() {
//     let (contract_address, _) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };
//     let non_admin: ContractAddress = 'non_admin'.try_into().unwrap();

//     start_cheat_caller_address(dispatcher.contract_address, non_admin);
//     dispatcher.add_candidate(candidate1_id);
// }

// #[test]
// fn test_election_start_automatically() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     //ADD CANDIDATES
//     add_candidates(dispatcher, ADMIN);

//     let hasElection_started = dispatcher.get_election_state();
//     assert!(
//         hasElection_started == true,
//         "Election should start automatically after adding five candidates",
//     );
// }

// #[test]
// fn test_user_can_vote() {
//     let user: ContractAddress = 'user'.try_into().unwrap();
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     //ADD CANDIDATE
//     add_candidates(dispatcher, ADMIN);

//     //USER VOTE & Expect Emit
//     start_cheat_caller_address(dispatcher.contract_address, user);
//     let mut spy = spy_events();
//     dispatcher.vote(candidate1_id);
//     spy.assert_emitted(@array![(dispatcher.contract_address, Event::Voted(Voted { voter: user
//     }))]);
// }

// #[test]
// #[should_panic(expected: 'election not started')]
// fn test_voter_cannot_vote_if_election_not_started() {
//     let voter: ContractAddress = 'voter'.try_into().unwrap();
//     let (contract_address, ADMIN) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };

//     //Add one candidate
//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     dispatcher.add_candidate(candidate1_id);
//     stop_cheat_caller_address(dispatcher.contract_address);

//     start_cheat_caller_address(dispatcher.contract_address, voter);
//     dispatcher.vote(candidate1_id);
// }

// #[test]
// #[should_panic(expected: 'candidate not found')]
// fn test_voter_cannot_vote_if_wrong_candidate_id() {
//     let non_existent_candidate_id = 10;
//     let voter: ContractAddress = 'voter'.try_into().unwrap();
//     let (contract_address, ADMIN) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };

//     //ADD CANDIDATES
//     add_candidates(dispatcher, ADMIN);

//     //Voter votes with the wrong candidate id
//     start_cheat_caller_address(dispatcher.contract_address, voter);
//     dispatcher.vote(non_existent_candidate_id);
// }
// #[test]
// #[should_panic(expected: 'candidate exists')]
// fn test_admin_cannot_add_a_candidate_more_than_once() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };

//     //Add same candidate twice and revert
//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     dispatcher.add_candidate(candidate1_id);
//     dispatcher.add_candidate(candidate1_id);
// }

// #[test]
// #[should_panic(expected: 'already voted')]
// fn test_voter_can_only_vote_once() {
//     let voter: ContractAddress = 'voter'.try_into().unwrap();
//     let (contract_address, ADMIN) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };

//     //ADD CANDIDATES
//     add_candidates(dispatcher, ADMIN);

//     //Voter try to vote more than once
//     start_cheat_caller_address(dispatcher.contract_address, voter);
//     dispatcher.vote(candidate1_id);
//     dispatcher.vote(candidate1_id);
// }

// #[test]
// fn test_admin_can_end_election() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };
//     let hasElection_started = dispatcher.get_election_state();

//     //ADD CANDIDATES
//     add_candidates(dispatcher, ADMIN);

//     //Voter cast their votes
//     multiple_voters__cast_vote(dispatcher);

//     //Admin Ends Election & Emits event
//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     let mut spy = spy_events();
//     dispatcher.end_election();
//     spy
//         .assert_emitted(
//             @array![(dispatcher.contract_address, Event::Election_Ended(Election_Ended {}))],
//         );

//     //Assert Election is not in progress
//     assert!(hasElection_started == false, "Election should have ended");
// }

// #[test]
// fn test_winner_is_correct() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };
//     let expected_winner_id = candidate1_id;

//     //ADD CANDIDATES
//     add_candidates(dispatcher, ADMIN);
//     //Voters cast their votes
//     multiple_voters__cast_vote(dispatcher);
//     //Admin Ends Election
//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     dispatcher.end_election();
//     let winner_id = dispatcher.get_winner();

//     //Assert it's the expected winner
//     assert!(winner_id == expected_winner_id, "Not the expected winner");
// }

// #[test]
// #[should_panic(expected: 'no votes cast')]
// fn test_no_vote_cast_and_election_ended() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");

//     let dispatcher = IVoteDispatcher { contract_address };

//     //ADD CANDIDATES
//     add_candidates(dispatcher, ADMIN);

//     //Admin Ends Election
//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     dispatcher.end_election();

//     dispatcher.get_winner();
// }

// #[test]
// fn test_calculates_right_votes() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     //ADD CANDIDATES
//     add_candidates(dispatcher, ADMIN);
//     //Voters cast their votes
//     multiple_voters__cast_vote(dispatcher);
//     //Admin Ends Election
//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     dispatcher.end_election();

//     //calculate_votes
//     let result = dispatcher.calculate_votes();
//     //array of tuple that has the candidate_id & candidate vote count
//     let expectedResult: Array<(u64, u64)> = array![
//         (candidate1_id, 3), (candidate2_id, 2), (candidate3_id, 1), (candidate4_id, 1),
//         (candidate5_id, 0),
//     ];
//     assert(result == expectedResult, 'wrong votes calculation');
// }

// fn add_candidates(contract: IVoteDispatcher, admin: ContractAddress) {
//     start_cheat_caller_address(contract.contract_address, admin);
//     contract.add_candidate(candidate1_id);
//     contract.add_candidate(candidate2_id);
//     contract.add_candidate(candidate3_id);
//     contract.add_candidate(candidate4_id);
//     contract.add_candidate(candidate5_id);
//     stop_cheat_caller_address(contract.contract_address);
// }

// fn multiple_voters__cast_vote(contract: IVoteDispatcher) {
//     let voter1: ContractAddress = 'voter1'.try_into().unwrap();
//     let voter2: ContractAddress = 'voter2'.try_into().unwrap();
//     let voter3: ContractAddress = 'voter3'.try_into().unwrap();
//     let voter4: ContractAddress = 'voter4'.try_into().unwrap();
//     let voter5: ContractAddress = 'voter5'.try_into().unwrap();
//     let voter6: ContractAddress = 'voter6'.try_into().unwrap();
//     let voter7: ContractAddress = 'voter7'.try_into().unwrap();

//     start_cheat_caller_address(contract.contract_address, voter1);
//     contract.vote(candidate1_id);
//     stop_cheat_caller_address(contract.contract_address);
//     start_cheat_caller_address(contract.contract_address, voter2);
//     contract.vote(candidate1_id);
//     stop_cheat_caller_address(contract.contract_address);
//     start_cheat_caller_address(contract.contract_address, voter3);
//     contract.vote(candidate1_id);
//     stop_cheat_caller_address(contract.contract_address);
//     start_cheat_caller_address(contract.contract_address, voter4);
//     contract.vote(candidate3_id);
//     stop_cheat_caller_address(contract.contract_address);
//     start_cheat_caller_address(contract.contract_address, voter5);
//     contract.vote(candidate4_id);
//     stop_cheat_caller_address(contract.contract_address);
//     start_cheat_caller_address(contract.contract_address, voter6);
//     contract.vote(candidate2_id);
//     stop_cheat_caller_address(contract.contract_address);
//     start_cheat_caller_address(contract.contract_address, voter7);
//     contract.vote(candidate2_id);
//     stop_cheat_caller_address(contract.contract_address);
// }

//////////////////////////////////////////////////////////////////////////////////////////////////////

// use snforge_std::{
//     ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
//     start_cheat_caller_address, stop_cheat_caller_address,
// };
// use starknet::{ContractAddress, SyscallResultTrait};
// use vote::Vote::{Candidate_Added, Election_Ended, Election_Started, Event, Voted};
// use vote::{IVoteDispatcher, IVoteDispatcherTrait};

// const candidate1_id: u64 = 1;
// const candidate2_id: u64 = 2;
// const candidate3_id: u64 = 3;
// const candidate4_id: u64 = 4;
// const candidate5_id: u64 = 5;

// fn deploy_contract(name: ByteArray) -> (ContractAddress, ContractAddress) {
//     let contract = declare(name).unwrap_syscall().contract_class();
//     let ADMIN: ContractAddress = 'admin'.try_into().unwrap();
//     let constructor_calldata = array![ADMIN.into()];
//     let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap_syscall();
//     (contract_address, ADMIN)
// }

// #[test]
// fn test_initial_state() {
//     let (contract_address, _) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     assert(dispatcher.get_election_state() == 0, 'should be NotStarted');
//     assert(dispatcher.get_candidates_length() == 0, 'no candidates initially');
// }

// #[test]
// fn test_admin_add_candidate() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);

//     let mut spy = spy_events();
//     dispatcher.add_candidate(candidate1_id);

//     spy
//         .assert_emitted(
//             @array![
//                 (
//                     dispatcher.contract_address,
//                     Event::Candidate_Added(Candidate_Added { candidate_id: candidate1_id }),
//                 ),
//             ],
//         );

//     assert(dispatcher.get_candidates_length() == 1, 'candidate should be added');
// }

// #[test]
// #[should_panic(expected: 'only admin')]
// fn test_only_admin_can_add_candidate() {
//     let (contract_address, _) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     let user: ContractAddress = 'user'.try_into().unwrap();

//     start_cheat_caller_address(dispatcher.contract_address, user);
//     dispatcher.add_candidate(candidate1_id);
// }

// #[test]
// fn test_start_election() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     add_candidates(dispatcher, ADMIN);

//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);

//     let mut spy = spy_events();
//     dispatcher.start_election();

//     spy
//         .assert_emitted(
//             @array![(dispatcher.contract_address, Event::Election_Started(Election_Started {}))],
//         );

//     assert(dispatcher.get_election_state() == 1, 'should be ongoing');
// }

// #[test]
// fn test_vote_success() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     add_candidates(dispatcher, ADMIN);
//     start_election(dispatcher, ADMIN);

//     let user: ContractAddress = 'user'.try_into().unwrap();

//     start_cheat_caller_address(dispatcher.contract_address, user);

//     let mut spy = spy_events();
//     dispatcher.vote(candidate1_id);

//     spy
//         .assert_emitted(
//             @array![
//                 (
//                     dispatcher.contract_address,
//                     Event::Voted(Voted { voter: user, candidate_id: candidate1_id }),
//                 ),
//             ],
//         );
// }

// #[test]
// #[should_panic(expected: 'election not active')]
// fn test_vote_before_election() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     add_candidates(dispatcher, ADMIN);

//     let user: ContractAddress = 'user'.try_into().unwrap();

//     start_cheat_caller_address(dispatcher.contract_address, user);
//     dispatcher.vote(candidate1_id);
// }

// #[test]
// #[should_panic(expected: 'already voted')]
// fn test_vote_twice() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     add_candidates(dispatcher, ADMIN);
//     start_election(dispatcher, ADMIN);

//     let user: ContractAddress = 'user'.try_into().unwrap();

//     start_cheat_caller_address(dispatcher.contract_address, user);
//     dispatcher.vote(candidate1_id);
//     dispatcher.vote(candidate1_id);
// }

// #[test]
// fn test_end_election() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     add_candidates(dispatcher, ADMIN);
//     start_election(dispatcher, ADMIN);

//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);

//     let mut spy = spy_events();
//     dispatcher.end_election();

//     spy
//         .assert_emitted(
//             @array![(dispatcher.contract_address, Event::Election_Ended(Election_Ended {}))],
//         );

//     assert(dispatcher.get_election_state() == 2, 'should be ended');
// }

// #[test]
// fn test_winner_correct() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     add_candidates(dispatcher, ADMIN);
//     start_election(dispatcher, ADMIN);

//     multiple_voters_cast_vote(dispatcher);

//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     dispatcher.end_election();

//     let winner = dispatcher.get_winner();
//     assert(winner == candidate1_id, 'wrong winner');
// }

// #[test]
// fn test_calculate_votes() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };

//     add_candidates(dispatcher, ADMIN);
//     start_election(dispatcher, ADMIN);

//     multiple_voters_cast_vote(dispatcher);

//     start_cheat_caller_address(dispatcher.contract_address, ADMIN);
//     dispatcher.end_election();

//     let result = dispatcher.calculate_votes();

//     let expected: Array<(u64, u64)> = array![
//         (candidate1_id, 3), (candidate2_id, 2), (candidate3_id, 1), (candidate4_id, 1),
//         (candidate5_id, 0),
//     ];

//     assert(result == expected, 'wrong results');
// }

// #[test]
// fn test_has_voted() {
//     let (contract_address, ADMIN) = deploy_contract("Vote");
//     let dispatcher = IVoteDispatcher { contract_address };
//     let voter = 'v1'.try_into().unwrap();

//     add_candidates(dispatcher, ADMIN);
//     start_election(dispatcher, ADMIN);
//     multiple_voters_cast_vote(dispatcher);

//     start_cheat_caller_address(dispatcher.contract_address, voter);
//     let voted = dispatcher.has_voted(voter);

//     assert(voted, 'already voted');
// }

// // /* ---------------- HELPERS ---------------- */

// fn add_candidates(contract: IVoteDispatcher, admin: ContractAddress) {
//     start_cheat_caller_address(contract.contract_address, admin);

//     contract.add_candidate(candidate1_id);
//     contract.add_candidate(candidate2_id);
//     contract.add_candidate(candidate3_id);
//     contract.add_candidate(candidate4_id);
//     contract.add_candidate(candidate5_id);

//     stop_cheat_caller_address(contract.contract_address);
// }

// fn start_election(contract: IVoteDispatcher, admin: ContractAddress) {
//     start_cheat_caller_address(contract.contract_address, admin);
//     contract.start_election();
//     stop_cheat_caller_address(contract.contract_address);
// }

// fn multiple_voters_cast_vote(contract: IVoteDispatcher) {
//     let voters = array![
//         ('v1'.try_into().unwrap(), candidate1_id), ('v2'.try_into().unwrap(), candidate1_id),
//         ('v3'.try_into().unwrap(), candidate1_id), ('v4'.try_into().unwrap(), candidate3_id),
//         ('v5'.try_into().unwrap(), candidate4_id), ('v6'.try_into().unwrap(), candidate2_id),
//         ('v7'.try_into().unwrap(), candidate2_id),
//     ];

//     let mut i = 0;
//     while i < voters.len() {
//         let (voter, candidate) = voters.at(i);

//         start_cheat_caller_address(contract.contract_address, *voter);
//         contract.vote(*candidate);
//         stop_cheat_caller_address(contract.contract_address);

//         i += 1;
//     }
// }

////////////////////////////////////////////////////////////////////////////////////////////////////////

use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, SyscallResultTrait};
use vote::Vote::{Candidate_Added, Election_Ended, Election_Reset, Election_Started, Event, Voted};
use vote::{IVoteDispatcher, IVoteDispatcherTrait};

const candidate1_id: u64 = 1;
const candidate2_id: u64 = 2;
const candidate3_id: u64 = 3;
const candidate4_id: u64 = 4;
const candidate5_id: u64 = 5;

// ── deploy
// ────────────────────────────────────────────────────────────────────

fn deploy_contract(name: ByteArray) -> (ContractAddress, ContractAddress) {
    let contract = declare(name).unwrap_syscall().contract_class();
    let ADMIN: ContractAddress = 'admin'.try_into().unwrap();
    let constructor_calldata = array![ADMIN.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap_syscall();
    (contract_address, ADMIN)
}

// ── initial state
// ─────────────────────────────────────────────────────────────

#[test]
fn test_initial_state() {
    let (contract_address, _) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    assert(dispatcher.get_election_state() == 0, 'should be NotStarted');
    assert(dispatcher.get_candidates_length() == 0, 'no candidates initially');
    // election_id starts at 0 — first round
    assert(dispatcher.get_election_id() == 0, 'election id should start at 0');
}

// ── add candidate
// ─────────────────────────────────────────────────────────────

#[test]
fn test_admin_add_candidate() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);

    let mut spy = spy_events();
    dispatcher.add_candidate(candidate1_id);

    spy
        .assert_emitted(
            @array![
                (
                    dispatcher.contract_address,
                    Event::Candidate_Added(Candidate_Added { candidate_id: candidate1_id }),
                ),
            ],
        );

    assert(dispatcher.get_candidates_length() == 1, 'candidate should be added');
}

#[test]
#[should_panic(expected: 'only admin')]
fn test_only_admin_can_add_candidate() {
    let (contract_address, _) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    let user: ContractAddress = 'user'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, user);
    dispatcher.add_candidate(candidate1_id);
}

#[test]
#[should_panic(expected: 'candidate exists')]
fn test_cannot_add_duplicate_candidate() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.add_candidate(candidate1_id);
    dispatcher.add_candidate(candidate1_id); // should panic
}

#[test]
#[should_panic(expected: 'max candidates reached')]
fn test_cannot_exceed_max_candidates() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.add_candidate(candidate1_id);
    dispatcher.add_candidate(candidate2_id);
    dispatcher.add_candidate(candidate3_id);
    dispatcher.add_candidate(candidate4_id);
    dispatcher.add_candidate(candidate5_id);
    dispatcher.add_candidate(6); // 6th candidate — should panic
}

// new guard: cannot add candidate once election has started
#[test]
#[should_panic(expected: 'election already started')]
fn test_cannot_add_candidate_after_election_starts() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.add_candidate(6); // should panic — election is ongoing
}

// ── start election
// ────────────────────────────────────────────────────────────

#[test]
fn test_start_election() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);

    let mut spy = spy_events();
    dispatcher.start_election();

    spy
        .assert_emitted(
            @array![(dispatcher.contract_address, Event::Election_Started(Election_Started {}))],
        );

    assert(dispatcher.get_election_state() == 1, 'should be Ongoing');
}

#[test]
#[should_panic(expected: 'not enough candidates')]
fn test_cannot_start_with_one_candidate() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    // only add one — start should panic
    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.add_candidate(candidate1_id);
    dispatcher.start_election();
}

#[test]
#[should_panic(expected: 'already started')]
fn test_cannot_start_election_twice() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.start_election(); // should panic
}

// ── vote
// ──────────────────────────────────────────────────────────────────────

#[test]
fn test_vote_success() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    let user: ContractAddress = 'user'.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, user);

    let mut spy = spy_events();
    dispatcher.vote(candidate1_id);

    spy
        .assert_emitted(
            @array![
                (
                    dispatcher.contract_address,
                    Event::Voted(Voted { voter: user, candidate_id: candidate1_id }),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'election not active')]
fn test_cannot_vote_before_election_starts() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    // intentionally NOT calling start_election

    let user: ContractAddress = 'user'.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, user);
    dispatcher.vote(candidate1_id);
}

#[test]
#[should_panic(expected: 'already voted')]
fn test_cannot_vote_twice() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    let user: ContractAddress = 'user'.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, user);
    dispatcher.vote(candidate1_id);
    dispatcher.vote(candidate1_id); // should panic
}

#[test]
#[should_panic(expected: 'candidate not found')]
fn test_cannot_vote_nonexistent_candidate() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    let user: ContractAddress = 'user'.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, user);
    dispatcher.vote(99); // does not exist
}

// ── has_voted
// ─────────────────────────────────────────────────────────────────

#[test]
fn test_has_voted_true_after_voting() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };
    let voter: ContractAddress = 'v1'.try_into().unwrap();

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, voter);
    dispatcher.vote(candidate1_id);

    // still in Ongoing state so has_voted won't panic
    assert(dispatcher.has_voted(voter), 'should have voted');
}

#[test]
fn test_has_voted_false_before_voting() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };
    let voter: ContractAddress = 'v1'.try_into().unwrap();

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, voter);
    assert(!dispatcher.has_voted(voter), 'should not have voted yet');
}

// ── end election
// ──────────────────────────────────────────────────────────────

#[test]
fn test_end_election() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);
    multiple_voters_cast_vote(dispatcher);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);

    let mut spy = spy_events();
    dispatcher.end_election();

    spy
        .assert_emitted(
            @array![(dispatcher.contract_address, Event::Election_Ended(Election_Ended {}))],
        );

    assert(dispatcher.get_election_state() == 2, 'should be Ended');
}

#[test]
#[should_panic(expected: 'not ongoing')]
fn test_cannot_end_election_if_not_started() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.end_election(); // not ongoing — should panic
}

// ── get_winner
// ────────────────────────────────────────────────────────────────

#[test]
fn test_winner_correct() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);
    multiple_voters_cast_vote(dispatcher);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.end_election();

    assert(dispatcher.get_winner() == candidate1_id, 'wrong winner');
}

#[test]
#[should_panic(expected: 'not ended')]
fn test_cannot_get_winner_before_election_ends() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);
    multiple_voters_cast_vote(dispatcher);

    // intentionally NOT calling end_election
    dispatcher.get_winner(); // should panic
}

#[test]
#[should_panic(expected: 'no votes cast')]
fn test_get_winner_panics_with_no_votes() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.end_election();

    dispatcher.get_winner(); // no votes were cast — should panic
}

// ── calculate_votes
// ───────────────────────────────────────────────────────────

#[test]
fn test_calculate_votes_correct() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);
    multiple_voters_cast_vote(dispatcher);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.end_election();

    let result = dispatcher.calculate_votes();
    let expected: Array<(u64, u64)> = array![
        (candidate1_id, 3), (candidate2_id, 2), (candidate3_id, 1), (candidate4_id, 1),
        (candidate5_id, 0),
    ];

    assert(result == expected, 'wrong vote counts');
}

// ── reset_vote_state
// ──────────────────────────────────────────────────────────

#[test]
fn test_reset_increments_election_id() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    assert(dispatcher.get_election_id() == 0, 'should start at 0');

    run_full_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.reset_vote_state();

    // election_id must now be 1
    assert(dispatcher.get_election_id() == 1, 'should be 1 after reset');
}

#[test]
fn test_reset_emits_event() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    run_full_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    let mut spy = spy_events();
    dispatcher.reset_vote_state();

    spy
        .assert_emitted(
            @array![
                (
                    dispatcher.contract_address,
                    Event::Election_Reset(Election_Reset { new_election_id: 1 }),
                ),
            ],
        );
}

#[test]
fn test_reset_clears_candidates() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    run_full_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.reset_vote_state();

    // new round has 0 candidates
    assert(dispatcher.get_candidates_length() == 0, 'candidates should be cleared');
}

#[test]
fn test_reset_sets_state_to_not_started() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    run_full_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.reset_vote_state();

    assert(dispatcher.get_election_state() == 0, 'should be NotStarted');
}

// after reset, voter from round 0 can vote again in round 1
// because the new election_id scopes their voter slot to a fresh key
#[test]
fn test_voter_can_vote_again_after_reset() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };
    let voter: ContractAddress = 'v1'.try_into().unwrap();

    // round 0
    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);
    start_cheat_caller_address(dispatcher.contract_address, voter);
    dispatcher.vote(candidate1_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.end_election();
    dispatcher.reset_vote_state();
    stop_cheat_caller_address(dispatcher.contract_address);

    // round 1 — fresh candidates, same voter should be allowed to vote
    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, voter);
    dispatcher.vote(candidate1_id); // should NOT panic — new election_id scopes the voter map
}

#[test]
fn test_multiple_resets_increment_id_correctly() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    let mut round: u32 = 0;
    while round < 3 {
        run_full_election(dispatcher, ADMIN);

        start_cheat_caller_address(dispatcher.contract_address, ADMIN);
        dispatcher.reset_vote_state();
        stop_cheat_caller_address(dispatcher.contract_address);

        round += 1;
    }

    assert(dispatcher.get_election_id() == 3, 'should be 3 after 3 resets');
}

#[test]
#[should_panic(expected: 'not ended')]
fn test_cannot_reset_if_not_ended() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    add_candidates(dispatcher, ADMIN);
    start_election(dispatcher, ADMIN);

    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.reset_vote_state(); // election is Ongoing — should panic
}

#[test]
#[should_panic(expected: 'only admin')]
fn test_only_admin_can_reset() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    run_full_election(dispatcher, ADMIN);

    let user: ContractAddress = 'user'.try_into().unwrap();
    start_cheat_caller_address(dispatcher.contract_address, user);
    dispatcher.reset_vote_state(); // should panic
}

// ── helpers
// ───────────────────────────────────────────────────────────────────

fn add_candidates(contract: IVoteDispatcher, admin: ContractAddress) {
    start_cheat_caller_address(contract.contract_address, admin);
    contract.add_candidate(candidate1_id);
    contract.add_candidate(candidate2_id);
    contract.add_candidate(candidate3_id);
    contract.add_candidate(candidate4_id);
    contract.add_candidate(candidate5_id);
    stop_cheat_caller_address(contract.contract_address);
}

fn start_election(contract: IVoteDispatcher, admin: ContractAddress) {
    start_cheat_caller_address(contract.contract_address, admin);
    contract.start_election();
    stop_cheat_caller_address(contract.contract_address);
}

fn multiple_voters_cast_vote(contract: IVoteDispatcher) {
    let voters = array![
        ('v1'.try_into().unwrap(), candidate1_id), ('v2'.try_into().unwrap(), candidate1_id),
        ('v3'.try_into().unwrap(), candidate1_id), ('v4'.try_into().unwrap(), candidate3_id),
        ('v5'.try_into().unwrap(), candidate4_id), ('v6'.try_into().unwrap(), candidate2_id),
        ('v7'.try_into().unwrap(), candidate2_id),
    ];

    let mut i = 0;
    while i < voters.len() {
        let (voter, candidate) = voters.at(i);
        start_cheat_caller_address(contract.contract_address, *voter);
        contract.vote(*candidate);
        stop_cheat_caller_address(contract.contract_address);
        i += 1;
    }
}

// runs a complete election cycle (add → start → vote → end) in one call
// used by reset tests that need a finished election to reset from
fn run_full_election(contract: IVoteDispatcher, admin: ContractAddress) {
    add_candidates(contract, admin);
    start_election(contract, admin);
    multiple_voters_cast_vote(contract);
    start_cheat_caller_address(contract.contract_address, admin);
    contract.end_election();
    stop_cheat_caller_address(contract.contract_address);
}
