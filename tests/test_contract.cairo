use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, SyscallResultTrait};
use vote::Vote::{Candidate_Added, Election_Ended, Event, Voted};
use vote::{IVoteDispatcher, IVoteDispatcherTrait};

fn deploy_contract(name: ByteArray) -> (ContractAddress, ContractAddress) {
    let contract = declare(name).unwrap_syscall().contract_class();
    let ADMIN: ContractAddress = 'admin'.try_into().unwrap();
    let constructor_calldata = array![ADMIN.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap_syscall();
    (contract_address, ADMIN)
}

#[test]
fn test_initial_election_state_is_false() {
    let (contract_address, _) = deploy_contract("Vote");

    let dispatcher = IVoteDispatcher { contract_address };
    let hasElection_started = dispatcher.get_election_state();

    assert(hasElection_started == false, 'Invalid Election state');
}

#[test]
fn test_no_initial_candidate() {
    let (contract_address, _) = deploy_contract("Vote");

    let dispatcher = IVoteDispatcher { contract_address };
    let candidate_length = dispatcher.get_candidates_length();

    assert!(candidate_length == 0, "Initial candidates length should be 0");
}

#[test]
fn test_admin_can_add_candidate() {
    let candidate_id = 1;
    let (contract_address, ADMIN) = deploy_contract("Vote");

    let dispatcher = IVoteDispatcher { contract_address };

    //ADD CANDIDATE AND ENSURE IT EMITS THE RIGHT EVENT
    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    let mut spy = spy_events();
    dispatcher.add_candidate(candidate_id);
    spy
        .assert_emitted(
            @array![
                (
                    dispatcher.contract_address,
                    Event::Candidate_Added(Candidate_Added { candidate_id: candidate_id }),
                ),
            ],
        );
    let candidate_length = dispatcher.get_candidates_length();

    //assert candidate Length is now one afting adding first candidate
    assert!(candidate_length == 1, "Candidate length should now be 1");
}

#[test]
#[should_panic(expected: 'only admin')]
fn test_only_admin_can_add_candidate() {
    let (contract_address, _) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };
    let non_admin: ContractAddress = 'non_admin'.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, non_admin);
    dispatcher.add_candidate(1);
}

#[test]
fn test_election_start_automatically() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    //ADD CANDIDATES
    add_candidates(dispatcher, ADMIN);

    let hasElection_started = dispatcher.get_election_state();
    assert!(
        hasElection_started == true,
        "Election should start automatically after adding five candidates",
    );
}

#[test]
fn test_user_can_vote() {
    let user: ContractAddress = 'user'.try_into().unwrap();
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };

    //ADD CANDIDATE
    add_candidates(dispatcher, ADMIN);

    //USER VOTE & Expect Emit
    start_cheat_caller_address(dispatcher.contract_address, user);
    let mut spy = spy_events();
    dispatcher.vote(1);
    spy.assert_emitted(@array![(dispatcher.contract_address, Event::Voted(Voted { voter: user }))]);
}

#[test]
#[should_panic(expected: 'election not started')]
fn test_voter_cannot_vote_if_election_not_started() {
    let voter: ContractAddress = 'voter'.try_into().unwrap();
    let (contract_address, ADMIN) = deploy_contract("Vote");

    let dispatcher = IVoteDispatcher { contract_address };

    //Add one candidate
    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.add_candidate(1);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, voter);
    dispatcher.vote(1);
}
#[test]
#[should_panic(expected: 'candidate exists')]
fn test_admin_cannot_add_a_candidate_more_than_once() {
    let (contract_address, ADMIN) = deploy_contract("Vote");

    let dispatcher = IVoteDispatcher { contract_address };

    //Add same candidate twice and revert
    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.add_candidate(1);
    dispatcher.add_candidate(1);
}

#[test]
#[should_panic(expected: 'already voted')]
fn test_voter_can_only_vote_once() {
    let voter: ContractAddress = 'voter'.try_into().unwrap();
    let (contract_address, ADMIN) = deploy_contract("Vote");

    let dispatcher = IVoteDispatcher { contract_address };

    //ADD CANDIDATES
    add_candidates(dispatcher, ADMIN);

    //Voter try to vote more than once
    start_cheat_caller_address(dispatcher.contract_address, voter);
    dispatcher.vote(1);
    dispatcher.vote(1);
}

#[test]
fn test_admin_can_end_election() {
    let (contract_address, ADMIN) = deploy_contract("Vote");

    let dispatcher = IVoteDispatcher { contract_address };
    let hasElection_started = dispatcher.get_election_state();

    //ADD CANDIDATES
    add_candidates(dispatcher, ADMIN);

    //Voter cast their votes
    multiple_voters__cast_vote(dispatcher);

    //Admin Ends Election & Emits event
    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    let mut spy = spy_events();
    dispatcher.end_election();
    spy
        .assert_emitted(
            @array![(dispatcher.contract_address, Event::Election_Ended(Election_Ended {}))],
        );

    //Assert Election is not in progress
    assert!(hasElection_started == false, "Election should have ended");
}

#[test]
fn test_winner_is_correct() {
    let (contract_address, ADMIN) = deploy_contract("Vote");
    let dispatcher = IVoteDispatcher { contract_address };
    let expected_winner_id = 1;

    //ADD CANDIDATES
    add_candidates(dispatcher, ADMIN);
    //Voters cast their votes
    multiple_voters__cast_vote(dispatcher);
    //Admin Ends Election
    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.end_election();
    let winner_id = dispatcher.get_winner();

    //Assert it's the expected winner
    assert!(winner_id == expected_winner_id, "Not the expected winner");
}

#[test]
#[should_panic(expected: 'no votes cast')]
fn test_no_vote_cast_and_election_ended() {
    let (contract_address, ADMIN) = deploy_contract("Vote");

    let dispatcher = IVoteDispatcher { contract_address };

    //ADD CANDIDATES
    add_candidates(dispatcher, ADMIN);

    //Admin Ends Election
    start_cheat_caller_address(dispatcher.contract_address, ADMIN);
    dispatcher.end_election();

    dispatcher.get_winner();
}


fn add_candidates(contract: IVoteDispatcher, admin: ContractAddress) {
    start_cheat_caller_address(contract.contract_address, admin);
    contract.add_candidate(1);
    contract.add_candidate(2);
    contract.add_candidate(3);
    contract.add_candidate(4);
    contract.add_candidate(5);
    stop_cheat_caller_address(contract.contract_address);
}

fn multiple_voters__cast_vote(contract: IVoteDispatcher) {
    let voter1: ContractAddress = 'voter1'.try_into().unwrap();
    let voter2: ContractAddress = 'voter2'.try_into().unwrap();
    let voter3: ContractAddress = 'voter3'.try_into().unwrap();
    let voter4: ContractAddress = 'voter4'.try_into().unwrap();
    let voter5: ContractAddress = 'voter5'.try_into().unwrap();
    let voter6: ContractAddress = 'voter6'.try_into().unwrap();
    let voter7: ContractAddress = 'voter7'.try_into().unwrap();

    start_cheat_caller_address(contract.contract_address, voter1);
    contract.vote(1);
    stop_cheat_caller_address(contract.contract_address);
    start_cheat_caller_address(contract.contract_address, voter2);
    contract.vote(1);
    stop_cheat_caller_address(contract.contract_address);
    start_cheat_caller_address(contract.contract_address, voter3);
    contract.vote(1);
    stop_cheat_caller_address(contract.contract_address);
    start_cheat_caller_address(contract.contract_address, voter4);
    contract.vote(3);
    stop_cheat_caller_address(contract.contract_address);
    start_cheat_caller_address(contract.contract_address, voter5);
    contract.vote(4);
    stop_cheat_caller_address(contract.contract_address);
    start_cheat_caller_address(contract.contract_address, voter6);
    contract.vote(2);
    stop_cheat_caller_address(contract.contract_address);
    start_cheat_caller_address(contract.contract_address, voter7);
    contract.vote(2);
    stop_cheat_caller_address(contract.contract_address);
}
