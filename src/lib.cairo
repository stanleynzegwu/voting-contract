#[starknet::interface]
pub trait IVote<TContractState> {
    fn end_election(ref self: TContractState);
    fn vote(ref self: TContractState, candidate_id: u64);
    fn add_candidate(ref self: TContractState, candidate_id: u64);
    fn get_winner(self: @TContractState) -> u64; // Returns winning candidate_id
    fn calculate_votes(self: @TContractState) -> Array<(u64, u64)>; // Returns (id, votes)
    fn get_election_state(self: @TContractState) -> bool;
    fn get_candidates_length(self: @TContractState) -> u64;
}

/// Simple contract for voting.
#[starknet::contract]
pub mod Vote {
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[derive(Drop, Serde, starknet::Store)]
    struct Candidate {
        id: u64,
        vote_count: u64,
    }

    //constants
    const MAX_CANDIDATES: u64 = 5;

    #[storage]
    struct Storage {
        admin: ContractAddress,
        election_started: bool,
        voters: Map<ContractAddress, bool>,
        candidates: Vec<Candidate>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Voted: Voted,
        Candidate_Added: Candidate_Added,
        Election_Ended: Election_Ended,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Voted {
        pub voter: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct Candidate_Added {
        pub candidate_id: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct Election_Ended {}

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
    }

    #[abi(embed_v0)]
    impl VoteImpl of super::IVote<ContractState> {
        fn end_election(ref self: ContractState) {
            only_admin(@self);

            self.election_started.write(false);
            self.emit(Election_Ended {});
        }

        fn vote(ref self: ContractState, candidate_id: u64) {
            let caller = get_caller_address();
            let hasVoted = self.voters.entry(caller).read();

            assert(self.election_started.read(), 'election not started');
            assert(!hasVoted, 'already voted');

            let mut i = 0;
            let len = self.candidates.len();
            let mut found = false;

            while i < len {
                let mut candidate = self.candidates.at(i).read();

                if candidate.id == candidate_id {
                    candidate.vote_count += 1;
                    self.candidates.at(i).write(candidate);
                    found = true;
                    break;
                }

                i += 1;
            }

            assert(found, 'candidate not found');

            self.voters.entry(caller).write(true);
            self.emit(Voted { voter: get_caller_address() });
        }


        fn add_candidate(ref self: ContractState, candidate_id: u64) {
            only_admin(@self);

            assert(self.candidates.len() < MAX_CANDIDATES, 'max candidates reached');

            // Check duplicate names
            let mut i = 0;
            let len = self.candidates.len();

            while i < len {
                let candidate = self.candidates.at(i).read();
                assert(candidate.id != candidate_id, 'candidate exists');
                i += 1;
            }

            let new_candidate = Candidate { id: candidate_id, vote_count: 0 };

            self.candidates.push(new_candidate);

            if self.candidates.len() == MAX_CANDIDATES {
                self.election_started.write(true);
            }

            self.emit(Candidate_Added { candidate_id });
        }

        fn calculate_votes(self: @ContractState) -> Array<(u64, u64)> {
            get_results(self)
        }

        ///GETTERS
        /// Returns the candidate_id with the highest vote count.
        ///
        /// Behavior:
        /// - The candidate with the strictly highest number of votes is selected.
        /// - In case of a tie, the first candidate with the highest vote count is returned.
        /// - Can only be called after the election has ended.
        fn get_winner(self: @ContractState) -> u64 {
            assert(!self.election_started.read(), 'election still ongoing');

            let mut winner_id = 0;
            let mut max_votes = 0;
            let mut i = 0;
            let len = self.candidates.len();

            while i < len {
                let candidate = self.candidates.at(i).read();
                if candidate.vote_count > max_votes {
                    max_votes = candidate.vote_count;
                    winner_id = candidate.id;
                }
                i += 1;
            }

            assert(max_votes > 0, 'no votes cast');
            winner_id
        }

        fn get_election_state(self: @ContractState) -> bool {
            self.election_started.read()
        }

        fn get_candidates_length(self: @ContractState) -> u64 {
            self.candidates.len()
        }
    }

    //internal functions
    fn only_admin(self: @ContractState) {
        let caller = get_caller_address();
        let admin = self.admin.read();
        assert(caller == admin, 'only admin');
    }

    fn get_results(self: @ContractState) -> Array<(u64, u64)> {
        let mut results = array![];
        let mut i = 0;
        let len = self.candidates.len();

        while i < len {
            let candidate = self.candidates.at(i).read();
            results.append((candidate.id, candidate.vote_count));
            i += 1;
        }

        results
    }
}
