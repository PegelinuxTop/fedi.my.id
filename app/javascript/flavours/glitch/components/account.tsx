import { useCallback, useMemo } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import classNames from 'classnames';

import MoreHorizIcon from '@/material-icons/400-24px/more_horiz.svg?react';
import {
  blockAccount,
  unblockAccount,
  muteAccount,
  unmuteAccount,
} from 'flavours/glitch/actions/accounts';
import { openModal } from 'flavours/glitch/actions/modal';
import { initMuteModal } from 'flavours/glitch/actions/mutes';
import { Avatar } from 'flavours/glitch/components/avatar';
import { AvatarOverlay } from 'flavours/glitch/components/avatar_overlay';
import { Button } from 'flavours/glitch/components/button';
import { FollowersCounter } from 'flavours/glitch/components/counters';
import { DisplayName } from 'flavours/glitch/components/display_name';
import { Dropdown } from 'flavours/glitch/components/dropdown_menu';
import { FollowButton } from 'flavours/glitch/components/follow_button';
import { RelativeTimestamp } from 'flavours/glitch/components/relative_timestamp';
import { ShortNumber } from 'flavours/glitch/components/short_number';
import { Skeleton } from 'flavours/glitch/components/skeleton';
import { VerifiedBadge } from 'flavours/glitch/components/verified_badge';
import type { MenuItem } from 'flavours/glitch/models/dropdown_menu';
import type { StatusReaction } from 'flavours/glitch/models/reaction';
import { useAppSelector, useAppDispatch } from 'flavours/glitch/store';

import { Permalink } from './permalink';

const messages = defineMessages({
  follow: { id: 'account.follow', defaultMessage: 'Follow' },
  unfollow: { id: 'account.unfollow', defaultMessage: 'Unfollow' },
  cancel_follow_request: {
    id: 'account.cancel_follow_request',
    defaultMessage: 'Withdraw follow request',
  },
  unblock: { id: 'account.unblock_short', defaultMessage: 'Unblock' },
  unmute: { id: 'account.unmute_short', defaultMessage: 'Unmute' },
  mute_notifications: {
    id: 'account.mute_notifications_short',
    defaultMessage: 'Mute notifications',
  },
  unmute_notifications: {
    id: 'account.unmute_notifications_short',
    defaultMessage: 'Unmute notifications',
  },
  mute: { id: 'account.mute_short', defaultMessage: 'Mute' },
  block: { id: 'account.block_short', defaultMessage: 'Block' },
  more: { id: 'status.more', defaultMessage: 'More' },
  addToLists: {
    id: 'account.add_or_remove_from_list',
    defaultMessage: 'Add or Remove from lists',
  },
  openOriginalPage: {
    id: 'account.open_original_page',
    defaultMessage: 'Open original page',
  },
});

export const Account: React.FC<{
  size?: number;
  overlayEmoji?: StatusReaction;
  id: string;
  hidden?: boolean;
  minimal?: boolean;
  defaultAction?: 'block' | 'mute';
  withBio?: boolean;
}> = ({
  id,
  size = 46,
  overlayEmoji = { name: null },
  hidden,
  minimal,
  defaultAction,
  withBio,
}) => {
  const intl = useIntl();
  const account = useAppSelector((state) => state.accounts.get(id));
  const relationship = useAppSelector((state) => state.relationships.get(id));
  const dispatch = useAppDispatch();
  const accountUrl = account?.url;

  const handleBlock = useCallback(() => {
    if (relationship?.blocking) {
      dispatch(unblockAccount(id));
    } else {
      dispatch(blockAccount(id));
    }
  }, [dispatch, id, relationship]);

  const handleMute = useCallback(() => {
    if (relationship?.muting) {
      dispatch(unmuteAccount(id));
    } else {
      dispatch(initMuteModal(account));
    }
  }, [dispatch, id, account, relationship]);

  const menu = useMemo(() => {
    let arr: MenuItem[] = [];

    if (defaultAction === 'mute') {
      const handleMuteNotifications = () => {
        dispatch(muteAccount(id, true));
      };

      const handleUnmuteNotifications = () => {
        dispatch(muteAccount(id, false));
      };

      arr = [
        {
          text: intl.formatMessage(
            relationship?.muting_notifications
              ? messages.unmute_notifications
              : messages.mute_notifications,
          ),
          action: relationship?.muting_notifications
            ? handleUnmuteNotifications
            : handleMuteNotifications,
        },
      ];
    } else if (defaultAction !== 'block') {
      const handleAddToLists = () => {
        dispatch(
          openModal({
            modalType: 'LIST_ADDER',
            modalProps: {
              accountId: id,
            },
          }),
        );
      };

      arr = [
        {
          text: intl.formatMessage(messages.addToLists),
          action: handleAddToLists,
        },
      ];

      if (accountUrl) {
        arr.unshift(
          {
            text: intl.formatMessage(messages.openOriginalPage),
            href: accountUrl,
          },
          null,
        );
      }
    }

    return arr;
  }, [dispatch, intl, id, accountUrl, relationship, defaultAction]);

  if (hidden) {
    return (
      <>
        {account?.display_name}
        {account?.username}
      </>
    );
  }

  let button: React.ReactNode, dropdown: React.ReactNode;

  if (menu.length > 0) {
    dropdown = (
      <Dropdown
        items={menu}
        icon='ellipsis-h'
        iconComponent={MoreHorizIcon}
        title={intl.formatMessage(messages.more)}
      />
    );
  }

  if (defaultAction === 'block') {
    button = (
      <Button
        text={intl.formatMessage(
          relationship?.blocking ? messages.unblock : messages.block,
        )}
        onClick={handleBlock}
      />
    );
  } else if (defaultAction === 'mute') {
    button = (
      <Button
        text={intl.formatMessage(
          relationship?.muting ? messages.unmute : messages.mute,
        )}
        onClick={handleMute}
      />
    );
  } else {
    button = <FollowButton accountId={id} />;
  }

  let muteTimeRemaining: React.ReactNode;

  if (account?.mute_expires_at) {
    muteTimeRemaining = (
      <>
        · <RelativeTimestamp timestamp={account.mute_expires_at} futureDate />
      </>
    );
  }

  let verification: React.ReactNode;

  const firstVerifiedField = account?.fields.find((item) => !!item.verified_at);

  if (firstVerifiedField) {
    verification = <VerifiedBadge link={firstVerifiedField.value} />;
  }

  let statusAvatar;
  if (!overlayEmoji.name) {
    statusAvatar = <Avatar account={account} size={size} />;
  } else {
    statusAvatar = <AvatarOverlay account={account} emoji={overlayEmoji} />;
  }

  return (
    <div className={classNames('account', { 'account--minimal': minimal })}>
      <div className='account__wrapper'>
        <Permalink
          className='account__display-name'
          title={account?.acct}
          href={account?.url}
          to={`/@${account?.acct}`}
          data-hover-card-account={id}
        >
          <div className='account__avatar-wrapper'>
            {account ? statusAvatar : <Skeleton width={size} height={size} />}
          </div>

          <div className='account__contents'>
            <DisplayName account={account} />

            {!minimal && (
              <div className='account__details'>
                {account ? (
                  <>
                    <ShortNumber
                      value={account.followers_count}
                      renderer={FollowersCounter}
                    />{' '}
                    {verification} {muteTimeRemaining}
                  </>
                ) : (
                  <Skeleton width='7ch' />
                )}
              </div>
            )}
          </div>
        </Permalink>

        {!minimal && (
          <div className='account__relationship'>
            {dropdown}
            {button}
          </div>
        )}
      </div>

      {account &&
        withBio &&
        (account.note.length > 0 ? (
          <div
            className='account__note translate'
            dangerouslySetInnerHTML={{ __html: account.note_emojified }}
          />
        ) : (
          <div className='account__note account__note--missing'>
            <FormattedMessage
              id='account.no_bio'
              defaultMessage='No description provided.'
            />
          </div>
        ))}
    </div>
  );
};
