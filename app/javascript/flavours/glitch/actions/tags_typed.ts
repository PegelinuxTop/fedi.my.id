import {
  apiGetTag,
  apiFollowTag,
  apiUnfollowTag,
} from 'flavours/glitch/api/tags';
import { createDataLoadingThunk } from 'flavours/glitch/store/typed_functions';

export const fetchHashtag = createDataLoadingThunk(
  'tags/fetch',
  ({ tagId }: { tagId: string }) => apiGetTag(tagId),
);

export const followHashtag = createDataLoadingThunk(
  'tags/follow',
  ({ tagId }: { tagId: string }) => apiFollowTag(tagId),
);

export const unfollowHashtag = createDataLoadingThunk(
  'tags/unfollow',
  ({ tagId }: { tagId: string }) => apiUnfollowTag(tagId),
);
