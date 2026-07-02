// Hand-written TypeScript convenience layer for @f3liz/mazemaze-api-hackerspub.
// Builds GraphQL request bodies directly; the melange-dist layer is for
// ReScript/OCaml consumers (./endpoints, ./melange-endpoints exports).
//
// Usage:
//   const c = connect("https://hackers.pub", { token: "my-session-id" })
//   const feed = await publicTimeline(c, { first: 20 })
// ============= connect / close =============
/**
 * Create a client for the hackers.pub GraphQL API.
 *
 * The default fetchFn POSTs `{ query, variables }` to `origin/graphql` with
 * `Authorization: Bearer <token>` when a token is present.  Pass a custom
 * `fetch` to override (e.g. for testing or non-browser environments).
 */
export function connect(origin, opts) {
    const token = opts?.token;
    const fetchFn = opts?.fetch ??
        ((method, url, body) => globalThis
            .fetch(url, {
            method,
            headers: {
                "Content-Type": "application/json",
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
            },
            body: JSON.stringify(body),
        })
            .then((r) => r.json()));
    return { origin, token, fetchFn };
}
/** No-op. Included for API symmetry with other mazemaze clients. */
export function close(_c) { }
// ============= internal helpers =============
function gql(c, query, variables) {
    const url = c.origin + "/graphql";
    return c.fetchFn("POST", url, { query, variables: variables ?? {} });
}
// ============= Queries =============
const POST_CARD_FIELDS = `
  __typename id uuid url
  content excerpt language published updated sensitive
  viewerHasBookmarked viewerHasShared
  actor { id handle name avatarUrl }
  media { id url type alt width height sensitive thumbnailUrl }
  engagementStats { replies shares reactions bookmarks quotes }
  reactionGroups {
    __typename
    reactors { totalCount viewerHasReacted }
    ... on EmojiReactionGroup { emoji }
    ... on CustomEmojiReactionGroup { customEmoji { id name imageUrl } }
  }
  replyTarget { __typename id uuid url actor { handle name } }
  sharedPost {
    __typename id uuid url content excerpt published language
    actor { handle name avatarUrl }
    media { id url type alt thumbnailUrl }
    ... on Article { slug publishedYear }
    ... on Note { visibility }
  }
  ... on Article { slug publishedYear }
  ... on Note { visibility sourceId }
  ... on Question {
    poll {
      id closed ends multiple viewerHasVoted
      options { index title viewerHasVoted votes { totalCount } }
    }
  }
`;
const PAGE_INFO = `pageInfo { endCursor hasNextPage }`;
export function publicTimeline(c, req) {
    return gql(c, `query PublicTimeline($after:String,$first:Int,$languages:[Locale!],$withoutShares:Boolean){
      publicTimeline(after:$after,first:$first,languages:$languages,withoutShares:$withoutShares){
        edges{cursor node{${POST_CARD_FIELDS}}}${PAGE_INFO}
      }
    }`, req);
}
export function personalTimeline(c, req) {
    return gql(c, `query PersonalTimeline($after:String,$first:Int,$languages:[Locale!],$withoutShares:Boolean){
      personalTimeline(after:$after,first:$first,languages:$languages,withoutShares:$withoutShares){
        edges{cursor node{${POST_CARD_FIELDS}}}${PAGE_INFO}
      }
    }`, req);
}
export function actorByHandle(c, req) {
    return gql(c, `query ActorByHandle($handle:String!,$allowLocalHandle:Boolean){
      actorByHandle(handle:$handle,allowLocalHandle:$allowLocalHandle){
        id handle handleHost name avatarUrl headerUrl bio local
        automaticallyApprovesFollowers created
        followsViewer
      }
    }`, req);
}
export function accountByUsername(c, req) {
    return gql(c, `query AccountByUsername($username:String!){
      accountByUsername(username:$username){
        id handle name
        actor{id handle handleHost name avatarUrl headerUrl bio local created automaticallyApprovesFollowers}
      }
    }`, req);
}
export function viewer(c) {
    return gql(c, `query Viewer{
      viewer{
        id handle name
        actor{id handle handleHost name avatarUrl headerUrl bio local}
      }
    }`);
}
export function postByUrl(c, req) {
    return gql(c, `query PostByUrl($url:String!){
      postByUrl(url:$url){
        ${POST_CARD_FIELDS}
      }
    }`, req);
}
export function postById(c, req) {
    return gql(c, `query PostById($id:ID!){
      node(id:$id){
        __typename id
        ... on Post { ${POST_CARD_FIELDS} }
      }
    }`, req);
}
export function postReplies(c, req) {
    return gql(c, `query PostReplies($id:ID!,$after:String,$first:Int){
      node(id:$id){
        __typename id
        ... on Post {
          replies(after:$after,first:$first){
            edges{cursor node{${POST_CARD_FIELDS}}}${PAGE_INFO}
          }
        }
      }
    }`, req);
}
export function actorPosts(c, req) {
    return gql(c, `query ActorPosts($handle:String!,$after:String,$first:Int){
      actorByHandle(handle:$handle){
        id handle name avatarUrl
        posts(after:$after,first:$first){
          edges{cursor node{${POST_CARD_FIELDS}}}${PAGE_INFO}
        }
      }
    }`, req);
}
export function actorPostsById(c, req) {
    return gql(c, `query ActorPostsById($id:ID!,$after:String,$first:Int){
      node(id:$id){
        __typename
        ... on Actor {
          id handle name avatarUrl
          posts(after:$after,first:$first){
            edges{cursor node{${POST_CARD_FIELDS}}}${PAGE_INFO}
          }
        }
      }
    }`, req);
}
const NOTIF_POST_FIELDS = `__typename id uuid url content excerpt published actor{handle name avatarUrl}`;
export function notifications(c, req) {
    return gql(c, `query Notifications($after:String,$first:Int){
      viewer{
        id
        notifications(after:$after,first:$first){
          edges{cursor node{
            __typename id uuid created
            actors(first:5){edges{node{id handle name avatarUrl}}}
            ... on MentionNotification{post{${NOTIF_POST_FIELDS}}}
            ... on ReplyNotification{post{${NOTIF_POST_FIELDS}}}
            ... on ReactNotification{emoji post{${NOTIF_POST_FIELDS}}}
            ... on ShareNotification{post{${NOTIF_POST_FIELDS}}}
            ... on QuoteNotification{post{${NOTIF_POST_FIELDS}}}
            ... on PollEndedNotification{post{${NOTIF_POST_FIELDS}}}
          }}${PAGE_INFO}
        }
      }
    }`, req);
}
// ============= Mutations =============
export function createNote(c, input) {
    return gql(c, `mutation CreateNote($input:CreateNoteInput!){
      createNote(input:$input){
        __typename
        ... on CreateNotePayload{note{id uuid url content published visibility}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
        ... on ActorSuspendedError{suspendedUntil}
      }
    }`, { input });
}
export function updateNote(c, input) {
    return gql(c, `mutation UpdateNote($input:UpdateNoteInput!){
      updateNote(input:$input){
        __typename
        ... on UpdateNotePayload{note{id uuid url content published updated visibility}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function deletePost(c, input) {
    return gql(c, `mutation DeletePost($input:DeletePostInput!){
      deletePost(input:$input){
        __typename
        ... on DeletePostPayload{deletedPostId}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function addReaction(c, input) {
    return gql(c, `mutation AddReaction($input:AddReactionToPostInput!){
      addReactionToPost(input:$input){
        __typename
        ... on AddReactionToPostPayload{clientMutationId}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
        ... on ActorSuspendedError{suspendedUntil}
      }
    }`, { input });
}
export function removeReaction(c, input) {
    return gql(c, `mutation RemoveReaction($input:RemoveReactionFromPostInput!){
      removeReactionFromPost(input:$input){
        __typename
        ... on RemoveReactionFromPostPayload{clientMutationId}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function bookmarkPost(c, input) {
    return gql(c, `mutation BookmarkPost($input:BookmarkPostInput!){
      bookmarkPost(input:$input){
        __typename
        ... on BookmarkPostPayload{post{id viewerHasBookmarked}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function unbookmarkPost(c, input) {
    return gql(c, `mutation UnbookmarkPost($input:UnbookmarkPostInput!){
      unbookmarkPost(input:$input){
        __typename
        ... on UnbookmarkPostPayload{unbookmarkedPostId post{id viewerHasBookmarked}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function sharePost(c, input) {
    return gql(c, `mutation SharePost($input:SharePostInput!){
      sharePost(input:$input){
        __typename
        ... on SharePostPayload{
          share{id uuid published}
          originalPost{id uuid viewerHasShared engagementStats{shares}}
        }
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
        ... on ActorSuspendedError{suspendedUntil}
      }
    }`, { input });
}
export function unsharePost(c, input) {
    return gql(c, `mutation UnsharePost($input:UnsharePostInput!){
      unsharePost(input:$input){
        __typename
        ... on UnsharePostPayload{originalPost{id uuid viewerHasShared engagementStats{shares}}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function followActor(c, input) {
    return gql(c, `mutation FollowActor($input:FollowActorInput!){
      followActor(input:$input){
        __typename
        ... on FollowActorPayload{
          followee{id handle automaticallyApprovesFollowers}
          follower{id handle}
        }
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
        ... on ActorSuspendedError{suspendedUntil}
      }
    }`, { input });
}
export function unfollowActor(c, input) {
    return gql(c, `mutation UnfollowActor($input:UnfollowActorInput!){
      unfollowActor(input:$input){
        __typename
        ... on UnfollowActorPayload{followee{id handle} follower{id handle}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function voteOnPoll(c, input) {
    return gql(c, `mutation VoteOnPoll($input:VoteOnPollInput!){
      voteOnPoll(input:$input){
        __typename
        ... on VoteOnPollPayload{
          poll{id closed multiple viewerHasVoted
            options{index title viewerHasVoted votes{totalCount}}}
        }
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
        ... on ActorSuspendedError{suspendedUntil}
      }
    }`, { input });
}
export function createMedium(c, input) {
    return gql(c, `mutation CreateMedium($input:CreateMediumInput!){
      createMedium(input:$input){
        __typename
        ... on CreateMediumPayload{medium{id uuid url type width height}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function startMediumUpload(c, input) {
    return gql(c, `mutation StartMediumUpload($input:StartMediumUploadInput!){
      startMediumUpload(input:$input){
        __typename
        ... on StartMediumUploadPayload{uploadId uploadUrl method expires headers{name value}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function finishMediumUpload(c, input) {
    return gql(c, `mutation FinishMediumUpload($input:FinishMediumUploadInput!){
      finishMediumUpload(input:$input){
        __typename
        ... on FinishMediumUploadPayload{medium{id uuid url type width height}}
        ... on InvalidInputError{inputPath}
        ... on NotAuthenticatedError{notAuthenticated}
      }
    }`, { input });
}
export function markNotificationsAsRead(c, req) {
    return gql(c, `mutation MarkNotificationsAsRead($upTo:UUID){markNotificationsAsRead(upTo:$upTo)}`, req);
}
// ============= Auth mutations =============
/**
 * Initiate passwordless sign-in by username.
 * Sends a magic link to the account's email; the link embeds `{token}` and
 * `{code}` as URI Template variables in `verifyUrl`.
 * Call `completeLoginChallenge` with those values to get a session token.
 */
export function loginByUsername(c, req) {
    return gql(c, `mutation LoginByUsername($username:String!,$locale:Locale!,$verifyUrl:URITemplate!){
      loginByUsername(username:$username,locale:$locale,verifyUrl:$verifyUrl){
        __typename
        ... on LoginChallenge{token}
        ... on AccountNotFoundError{query}
      }
    }`, req);
}
/**
 * Initiate passwordless sign-in by email.
 * Same flow as `loginByUsername` but keyed on email address.
 */
export function loginByEmail(c, req) {
    return gql(c, `mutation LoginByEmail($email:String!,$locale:Locale!,$verifyUrl:URITemplate!){
      loginByEmail(email:$email,locale:$locale,verifyUrl:$verifyUrl){
        __typename
        ... on LoginChallenge{token}
        ... on AccountNotFoundError{query}
      }
    }`, req);
}
/**
 * Exchange the `(token, code)` pair from a magic-link email for a session.
 * On success, `data.completeLoginChallenge.id` is the **bearer token** to
 * pass as `opts.token` when calling `connect`.
 */
export function completeLoginChallenge(c, req) {
    return gql(c, `mutation CompleteLoginChallenge($token:UUID!,$code:String!){
      completeLoginChallenge(token:$token,code:$code){
        __typename
        ... on Session{id created account{id handle name actor{avatarUrl}}}
        ... on AccountBannedError{since}
      }
    }`, req);
}
