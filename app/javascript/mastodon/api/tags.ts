import api, { getLinks, apiRequestPost, apiRequestGet } from 'mastodon/api';
import type { ApiHashtagJSON } from 'mastodon/api_types/tags';

export const apiGetTag = (tagId: string) =>
  apiRequestGet<ApiHashtagJSON>(`v1/tags/${tagId}`);

export const apiFollowTag = (tagId: string) =>
  apiRequestPost<ApiHashtagJSON>(`v1/tags/${tagId}/follow`);

export const apiUnfollowTag = (tagId: string) =>
  apiRequestPost<ApiHashtagJSON>(`v1/tags/${tagId}/unfollow`);

export const apiGetFollowedTags = async (url?: string) => {
  const response = await api().request<ApiHashtagJSON[]>({
    method: 'GET',
    url: url ?? '/api/v1/followed_tags',
  });

  return {
    tags: response.data,
    links: getLinks(response),
  };
};
