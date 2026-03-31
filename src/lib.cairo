// #[starknet::interface]
// pub trait IVote<TContractState> {
//     fn end_election(ref self: TContractState);
//     fn vote(ref self: TContractState, candidate_id: u64);
//     fn add_candidate(ref self: TContractState, candidate_id: u64);
//     fn get_winner(self: @TContractState) -> u64; // Returns winning candidate_id
//     fn calculate_votes(self: @TContractState) -> Array<(u64, u64)>; // Returns (id, votes)
//     fn get_election_state(self: @TContractState) -> bool;
//     fn get_candidates_length(self: @TContractState) -> u64;
// }

// /// Simple contract for voting.
// #[starknet::contract]
// pub mod Vote {
//     use starknet::storage::{
//         Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess,
//         StoragePointerWriteAccess, Vec, VecTrait,
//     };
//     use starknet::{ContractAddress, get_caller_address};

//     #[derive(Drop, Serde, starknet::Store)]
//     struct Candidate {
//         id: u64,
//         vote_count: u64,
//     }

//     //constants
//     const MAX_CANDIDATES: u64 = 5;

//     #[storage]
//     struct Storage {
//         admin: ContractAddress,
//         election_started: bool,
//         voters: Map<ContractAddress, bool>,
//         candidates: Vec<Candidate>,
//     }

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     pub enum Event {
//         Voted: Voted,
//         Candidate_Added: Candidate_Added,
//         Election_Ended: Election_Ended,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct Voted {
//         pub voter: ContractAddress,
//     }
//     #[derive(Drop, starknet::Event)]
//     pub struct Candidate_Added {
//         pub candidate_id: u64,
//     }
//     #[derive(Drop, starknet::Event)]
//     pub struct Election_Ended {}

//     #[constructor]
//     fn constructor(ref self: ContractState, admin: ContractAddress) {
//         self.admin.write(admin);
//     }

//     #[abi(embed_v0)]
//     impl VoteImpl of super::IVote<ContractState> {
//         fn end_election(ref self: ContractState) {
//             only_admin(@self);

//             self.election_started.write(false);
//             self.emit(Election_Ended {});
//         }

//         fn vote(ref self: ContractState, candidate_id: u64) {
//             let caller = get_caller_address();
//             let hasVoted = self.voters.entry(caller).read();

//             assert(self.election_started.read(), 'election not started');
//             assert(!hasVoted, 'already voted');

//             let mut i = 0;
//             let len = self.candidates.len();
//             let mut found = false;

//             while i < len {
//                 let mut candidate = self.candidates.at(i).read();

//                 if candidate.id == candidate_id {
//                     candidate.vote_count += 1;
//                     self.candidates.at(i).write(candidate);
//                     found = true;
//                     break;
//                 }

//                 i += 1;
//             }

//             assert(found, 'candidate not found');

//             self.voters.entry(caller).write(true);
//             self.emit(Voted { voter: get_caller_address() });
//         }

//         fn add_candidate(ref self: ContractState, candidate_id: u64) {
//             only_admin(@self);

//             assert(self.candidates.len() < MAX_CANDIDATES, 'max candidates reached');

//             // Check duplicate names
//             let mut i = 0;
//             let len = self.candidates.len();

//             while i < len {
//                 let candidate = self.candidates.at(i).read();
//                 assert(candidate.id != candidate_id, 'candidate exists');
//                 i += 1;
//             }

//             let new_candidate = Candidate { id: candidate_id, vote_count: 0 };

//             self.candidates.push(new_candidate);

//             if self.candidates.len() == MAX_CANDIDATES {
//                 self.election_started.write(true);
//             }

//             self.emit(Candidate_Added { candidate_id });
//         }

//         fn calculate_votes(self: @ContractState) -> Array<(u64, u64)> {
//             get_results(self)
//         }

//         ///GETTERS
//         /// Returns the candidate_id with the highest vote count.
//         ///
//         /// Behavior:
//         /// - The candidate with the strictly highest number of votes is selected.
//         /// - In case of a tie, the first candidate with the highest vote count is returned.
//         /// - Can only be called after the election has ended.
//         fn get_winner(self: @ContractState) -> u64 {
//             assert(!self.election_started.read(), 'election still ongoing');

//             let mut winner_id = 0;
//             let mut max_votes = 0;
//             let mut i = 0;
//             let len = self.candidates.len();

//             while i < len {
//                 let candidate = self.candidates.at(i).read();
//                 if candidate.vote_count > max_votes {
//                     max_votes = candidate.vote_count;
//                     winner_id = candidate.id;
//                 }
//                 i += 1;
//             }

//             assert(max_votes > 0, 'no votes cast');
//             winner_id
//         }

//         fn get_election_state(self: @ContractState) -> bool {
//             self.election_started.read()
//         }

//         fn get_candidates_length(self: @ContractState) -> u64 {
//             self.candidates.len()
//         }
//     }

//     //internal functions
//     fn only_admin(self: @ContractState) {
//         let caller = get_caller_address();
//         let admin = self.admin.read();
//         assert(caller == admin, 'only admin');
//     }

//     fn get_results(self: @ContractState) -> Array<(u64, u64)> {
//         let mut results = array![];
//         let mut i = 0;
//         let len = self.candidates.len();

//         while i < len {
//             let candidate = self.candidates.at(i).read();
//             results.append((candidate.id, candidate.vote_count));
//             i += 1;
//         }

//         results
//     }
// }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// use starknet::ContractAddress;

// #[starknet::interface]
// pub trait IVote<TContractState> {
//     // --- Admin functions ---
//     fn start_election(ref self: TContractState);
//     fn end_election(ref self: TContractState);
//     fn add_candidate(ref self: TContractState, candidate_id: u64);

//     // --- User function ---
//     fn vote(ref self: TContractState, candidate_id: u64);

//     // --- View functions ---
//     fn get_winner(self: @TContractState) -> u64; // winning candidate_id

//     fn calculate_votes(self: @TContractState) -> Array<(u64, u64)>;
//     // (candidate_id, vote_count)

//     fn get_candidate(self: @TContractState, candidate_id: u64) -> (u64, u64);
//     // (candidate_id, vote_count)

//     fn get_election_state(self: @TContractState) -> u8;
//     // 0 = NotStarted, 1 = Ongoing, 2 = Ended

//     fn get_candidates_length(self: @TContractState) -> u64;

//     fn has_voted(self: @TContractState, voter_address: ContractAddress) -> bool;
// }

// #[starknet::contract]
// pub mod Vote {
//     use starknet::storage::{
//         Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess,
//         StoragePointerWriteAccess, Vec, VecTrait,
//     };
//     use starknet::{ContractAddress, get_caller_address};

//     #[derive(Drop, Serde, starknet::Store)]
//     struct Candidate {
//         id: u64,
//         vote_count: u64,
//     }

//     #[derive(Drop, Serde, starknet::Store, PartialEq)]
//     enum ElectionState {
//         #[default]
//         NotStarted,
//         Ongoing,
//         Ended,
//     }

//     const MAX_CANDIDATES: u64 = 5;

//     #[storage]
//     struct Storage {
//         admin: ContractAddress,
//         election_state: ElectionState,
//         voters: Map<ContractAddress, bool>,
//         candidates: Map<u64, Candidate>,
//         candidate_ids: Vec<u64>,
//     }

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     pub enum Event {
//         Voted: Voted,
//         Candidate_Added: Candidate_Added,
//         Election_Started: Election_Started,
//         Election_Ended: Election_Ended,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct Voted {
//         pub voter: ContractAddress,
//         pub candidate_id: u64,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct Candidate_Added {
//         pub candidate_id: u64,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct Election_Started {}

//     #[derive(Drop, starknet::Event)]
//     pub struct Election_Ended {}

//     #[constructor]
//     fn constructor(ref self: ContractState, admin: ContractAddress) {
//         self.admin.write(admin);
//         self.election_state.write(ElectionState::NotStarted);
//     }

//     #[abi(embed_v0)]
//     impl VoteImpl of super::IVote<ContractState> {
//         fn start_election(ref self: ContractState) {
//             only_admin(@self);

//             assert(self.candidate_ids.len() > 1, 'not enough candidates');
//             assert(self.election_state.read() == ElectionState::NotStarted, 'already started');

//             self.election_state.write(ElectionState::Ongoing);
//             self.emit(Election_Started {});
//         }

//         fn end_election(ref self: ContractState) {
//             only_admin(@self);

//             assert(self.election_state.read() == ElectionState::Ongoing, 'not ongoing');

//             self.election_state.write(ElectionState::Ended);
//             self.emit(Election_Ended {});
//         }

//         fn add_candidate(ref self: ContractState, candidate_id: u64) {
//             only_admin(@self);

//             assert(self.candidate_ids.len() < MAX_CANDIDATES, 'max candidates reached');

//             let existing = self.candidates.entry(candidate_id).read();
//             assert(existing.id == 0, 'candidate exists');

//             let new_candidate = Candidate { id: candidate_id, vote_count: 0 };

//             self.candidates.entry(candidate_id).write(new_candidate);
//             self.candidate_ids.push(candidate_id);

//             self.emit(Candidate_Added { candidate_id });
//         }

//         fn vote(ref self: ContractState, candidate_id: u64) {
//             let caller = get_caller_address();

//             assert(self.election_state.read() == ElectionState::Ongoing, 'election not active');
//             assert(!self.voters.entry(caller).read(), 'already voted');

//             let mut candidate = self.candidates.entry(candidate_id).read();
//             assert(candidate.id != 0, 'candidate not found');

//             candidate.vote_count += 1;
//             self.candidates.entry(candidate_id).write(candidate);

//             self.voters.entry(caller).write(true);

//             self.emit(Voted { voter: caller, candidate_id });
//         }

//         fn calculate_votes(self: @ContractState) -> Array<(u64, u64)> {
//             let mut results = array![];

//             let mut i = 0;
//             let len = self.candidate_ids.len();

//             while i < len {
//                 let id = self.candidate_ids.at(i).read();
//                 let candidate = self.candidates.entry(id).read();

//                 results.append((id, candidate.vote_count));
//                 i += 1;
//             }

//             results
//         }

//         fn get_winner(self: @ContractState) -> u64 {
//             assert(self.election_state.read() == ElectionState::Ended, 'not ended');

//             let mut winner_id = 0;
//             let mut max_votes = 0;

//             let mut i = 0;
//             let len = self.candidate_ids.len();

//             while i < len {
//                 let id = self.candidate_ids.at(i).read();
//                 let candidate = self.candidates.entry(id).read();

//                 if candidate.vote_count > max_votes {
//                     max_votes = candidate.vote_count;
//                     winner_id = id;
//                 }

//                 i += 1;
//             }

//             assert(max_votes > 0, 'no votes cast');
//             winner_id
//         }

//         fn get_candidate(self: @ContractState, candidate_id: u64) -> (u64, u64) {
//             let candidate = self.candidates.entry(candidate_id).read();
//             assert(candidate.id != 0, 'candidate not found');

//             (candidate.id, candidate.vote_count)
//         }

//         fn get_election_state(self: @ContractState) -> u8 {
//             match self.election_state.read() {
//                 ElectionState::NotStarted => 0,
//                 ElectionState::Ongoing => 1,
//                 ElectionState::Ended => 2,
//             }
//         }

//         fn get_candidates_length(self: @ContractState) -> u64 {
//             self.candidate_ids.len()
//         }

//         fn has_voted(self: @ContractState, voter_address: ContractAddress) -> bool {
//             assert(self.election_state.read() == ElectionState::Ongoing, 'not ongoing');
//             self.voters.entry(voter_address).read()
//         }
//     }

//     fn only_admin(self: @ContractState) {
//         let caller = get_caller_address();
//         let admin = self.admin.read();
//         assert(caller == admin, 'only admin');
//     }
// }

////////////////////////////////////////////////////////////////////////////////////////////////////////

use starknet::ContractAddress;

#[starknet::interface]
pub trait IVote<TContractState> {
    fn start_election(ref self: TContractState);
    fn end_election(ref self: TContractState);
    fn add_candidate(ref self: TContractState, candidate_id: u64);
    fn reset_vote_state(ref self: TContractState);
    fn vote(ref self: TContractState, candidate_id: u64);

    fn get_winner(self: @TContractState) -> u64;
    fn calculate_votes(self: @TContractState) -> Array<(u64, u64)>;
    fn get_candidate(self: @TContractState, candidate_id: u64) -> (u64, u64);
    fn get_election_state(self: @TContractState) -> u8;
    fn get_candidates_length(self: @TContractState) -> u64;
    fn has_voted(self: @TContractState, voter_address: ContractAddress) -> bool;
    fn get_election_id(self: @TContractState) -> u64;
}

#[starknet::contract]
pub mod Vote {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[derive(Drop, Serde, starknet::Store)]
    struct Candidate {
        id: u64,
        vote_count: u64,
    }

    #[derive(Drop, Serde, starknet::Store, PartialEq)]
    enum ElectionState {
        #[default]
        NotStarted,
        Ongoing,
        Ended,
    }

    const MAX_CANDIDATES: u64 = 5;

    #[storage]
    struct Storage {
        admin: ContractAddress,
        election_id: u64,
        election_state: ElectionState,
        // versioned by election_id
        voters: Map<(u64, ContractAddress), bool>,
        candidates: Map<(u64, u64), Candidate>, // (election_id, candidate_id) -> Candidate
        candidate_ids: Map<(u64, u64), u64>, // (election_id, index) -> candidate_id
        candidates_count: Map<u64, u64> // election_id -> count
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Voted: Voted,
        Candidate_Added: Candidate_Added,
        Election_Started: Election_Started,
        Election_Ended: Election_Ended,
        Election_Reset: Election_Reset,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Voted {
        pub voter: ContractAddress,
        pub candidate_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Candidate_Added {
        pub candidate_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Election_Started {}

    #[derive(Drop, starknet::Event)]
    pub struct Election_Ended {}

    #[derive(Drop, starknet::Event)]
    pub struct Election_Reset {
        pub new_election_id: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.election_id.write(0);
        self.election_state.write(ElectionState::NotStarted);
    }

    #[abi(embed_v0)]
    impl VoteImpl of super::IVote<ContractState> {
        fn add_candidate(ref self: ContractState, candidate_id: u64) {
            only_admin(@self);
            assert(
                self.election_state.read() == ElectionState::NotStarted, 'election already started',
            );

            let eid = self.election_id.read();
            let count = self.candidates_count.entry(eid).read();

            assert(count < MAX_CANDIDATES, 'max candidates reached');

            let existing = self.candidates.entry((eid, candidate_id)).read();
            assert(existing.id == 0, 'candidate exists');

            self
                .candidates
                .entry((eid, candidate_id))
                .write(Candidate { id: candidate_id, vote_count: 0 });
            self.candidate_ids.entry((eid, count)).write(candidate_id);
            self.candidates_count.entry(eid).write(count + 1);

            self.emit(Candidate_Added { candidate_id });
        }

        fn start_election(ref self: ContractState) {
            only_admin(@self);

            let eid = self.election_id.read();
            assert(self.candidates_count.entry(eid).read() > 1, 'not enough candidates');
            assert(self.election_state.read() == ElectionState::NotStarted, 'already started');

            self.election_state.write(ElectionState::Ongoing);
            self.emit(Election_Started {});
        }

        fn end_election(ref self: ContractState) {
            only_admin(@self);
            assert(self.election_state.read() == ElectionState::Ongoing, 'not ongoing');

            self.election_state.write(ElectionState::Ended);
            self.emit(Election_Ended {});
        }

        fn reset_vote_state(ref self: ContractState) {
            only_admin(@self);
            assert(self.election_state.read() == ElectionState::Ended, 'not ended');

            let new_id = self.election_id.read() + 1;
            self.election_id.write(new_id);
            self.election_state.write(ElectionState::NotStarted);

            self.emit(Election_Reset { new_election_id: new_id });
        }

        fn vote(ref self: ContractState, candidate_id: u64) {
            let caller = get_caller_address();
            let eid = self.election_id.read();

            assert(self.election_state.read() == ElectionState::Ongoing, 'election not active');
            assert(!self.voters.entry((eid, caller)).read(), 'already voted');

            let mut candidate = self.candidates.entry((eid, candidate_id)).read();
            assert(candidate.id != 0, 'candidate not found');

            candidate.vote_count += 1;
            self.candidates.entry((eid, candidate_id)).write(candidate);
            self.voters.entry((eid, caller)).write(true);

            self.emit(Voted { voter: caller, candidate_id });
        }

        fn get_winner(self: @ContractState) -> u64 {
            assert(self.election_state.read() == ElectionState::Ended, 'not ended');

            let eid = self.election_id.read();
            let count = self.candidates_count.entry(eid).read();
            let mut winner_id = 0;
            let mut max_votes = 0;
            let mut i = 0;

            while i < count {
                let id = self.candidate_ids.entry((eid, i)).read();
                let candidate = self.candidates.entry((eid, id)).read();
                if candidate.vote_count > max_votes {
                    max_votes = candidate.vote_count;
                    winner_id = id;
                }
                i += 1;
            }

            assert(max_votes > 0, 'no votes cast');
            winner_id
        }

        fn calculate_votes(self: @ContractState) -> Array<(u64, u64)> {
            let eid = self.election_id.read();
            let count = self.candidates_count.entry(eid).read();
            let mut results = array![];
            let mut i = 0;

            while i < count {
                let id = self.candidate_ids.entry((eid, i)).read();
                let candidate = self.candidates.entry((eid, id)).read();
                results.append((id, candidate.vote_count));
                i += 1;
            }

            results
        }

        fn get_candidate(self: @ContractState, candidate_id: u64) -> (u64, u64) {
            let eid = self.election_id.read();
            let candidate = self.candidates.entry((eid, candidate_id)).read();
            assert(candidate.id != 0, 'candidate not found');
            (candidate.id, candidate.vote_count)
        }

        fn get_election_state(self: @ContractState) -> u8 {
            match self.election_state.read() {
                ElectionState::NotStarted => 0,
                ElectionState::Ongoing => 1,
                ElectionState::Ended => 2,
            }
        }

        fn get_candidates_length(self: @ContractState) -> u64 {
            let eid = self.election_id.read();
            self.candidates_count.entry(eid).read()
        }

        fn has_voted(self: @ContractState, voter_address: ContractAddress) -> bool {
            assert(self.election_state.read() == ElectionState::Ongoing, 'not ongoing');
            let eid = self.election_id.read();
            self.voters.entry((eid, voter_address)).read()
        }

        fn get_election_id(self: @ContractState) -> u64 {
            self.election_id.read()
        }
    }

    fn only_admin(self: @ContractState) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'only admin');
    }
}
