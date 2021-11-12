import _ from 'underscore';
import { FlowRouter } from 'meteor/kadira:flow-router';
import moment from 'moment';
import toastr from 'toastr';
import mem from 'mem';
import { Meteor } from 'meteor/meteor';
import { TAPi18n } from 'meteor/rocketchat:tap-i18n';
import { ReactiveVar } from 'meteor/reactive-var';
import { Tracker } from 'meteor/tracker';
import { Session } from 'meteor/session';
import { messageArgs } from './messageArgs';
import { roomTypes, canDeleteMessage } from '../../../utils/client';
import { Messages, Rooms, Subscriptions } from '../../../models/client';
import { hasAtLeastOnePermission } from '../../../authorization/client';

const call = (method, ...args) => new Promise((resolve, reject) => {
	Meteor.call(method, ...args, function(err, data) {
		if (err) {
			return reject(err);
		}
		resolve(data);
	});
});

export const addMessageToList = (messagesList, message) => {
	// checks if the message is not already on the list
	if (!messagesList.find(({ _id }) => _id === message._id)) {
		messagesList.push(message);
	}

	return messagesList;
};

export const MessageAction = new class {
	/*
  	config expects the following keys (only id is mandatory):
  		id (mandatory)
  		icon: string
  		label: string
  		action: function(event, instance)
  		condition: function(message)
			order: integer
			group: string (message or menu)
   */

	constructor() {
		this.buttons = new ReactiveVar({});
	}

	addButton(config) {
		if (!config || !config.id) {
			return false;
		}

		if (!config.group) {
			config.group = 'menu';
		}

		if (config.condition) {
			config.condition = mem(config.condition, { maxAge: 1000, cacheKey: JSON.stringify });
		}

		return Tracker.nonreactive(() => {
			const btns = this.buttons.get();
			btns[config.id] = config;
			mem.clear(this._getButtons);
			mem.clear(this._getButtonsByGroup);
			return this.buttons.set(btns);
		});
	}

	removeButton(id) {
		return Tracker.nonreactive(() => {
			const btns = this.buttons.get();
			delete btns[id];
			return this.buttons.set(btns);
		});
	}

	updateButton(id, config) {
		return Tracker.nonreactive(() => {
			const btns = this.buttons.get();
			if (btns[id]) {
				btns[id] = _.extend(btns[id], config);
				return this.buttons.set(btns);
			}
		});
	}

	getButtonById(id) {
		const allButtons = this.buttons.get();
		return allButtons[id];
	}

	_getButtons = mem(function() {
		return _.sortBy(_.toArray(this.buttons.get()), 'order');
	})

	_getButtonsByGroup = mem(function(group) {
		return this._getButtons().filter((button) => (Array.isArray(button.group) ? button.group.includes(group) : button.group === group));
	})

	getButtons(message, context, group) {
		const allButtons = group ? this._getButtonsByGroup(group) : this._getButtons();

		if (message) {
			return allButtons.filter(function(button) {
				if (button.context == null || button.context.includes(context)) {
					return button.condition == null || button.condition(message, context);
				}
				return false;
			});
		}
		return allButtons;
	}

	resetButtons() {
		mem.clear(this._getButtons);
		mem.clear(this._getButtonsByGroup);
		return this.buttons.set({});
	}

	async getPermaLink(msgId) {
		if (!msgId) {
			throw new Error('invalid-parameter');
		}

		const msg = Messages.findOne(msgId) || await call('getSingleMessage', msgId);
		if (!msg) {
			throw new Error('message-not-found');
		}
		const roomData = Rooms.findOne({
			_id: msg.rid,
		});

		if (!roomData) {
			throw new Error('room-not-found');
		}

		const subData = Subscriptions.findOne({ rid: roomData._id, 'u._id': Meteor.userId() });
		const roomURL = roomTypes.getURL(roomData.t, subData || roomData);
		return `${ roomURL }?msg=${ msgId }`;
	}
}();

Meteor.startup(async function() {
	const { chatMessages } = await import('../../../ui');

	const getChatMessagesFrom = (msg) => {
		const { rid = Session.get('openedRoom'), tmid = msg._id } = msg;

		return chatMessages[`${ rid }-${ tmid }`] || chatMessages[rid];
	};

	MessageAction.addButton({
		id: 'edit-message',
		icon: 'edit',
		label: 'Edit',
		context: ['message', 'message-mobile', 'threads'],
		action() {
			const { msg } = messageArgs(this);
			getChatMessagesFrom(msg).edit(document.getElementById(msg.tmid ? `thread-${ msg._id }` : msg._id));
		},
		condition({ msg: message, subscription, settings }) {
			if (subscription == null) {
				return false;
			}
			const hasPermission = hasAtLeastOnePermission('edit-message', message.rid);
			const isEditAllowed = settings.Message_AllowEditing;
			const editOwn = message.u && message.u._id === Meteor.userId();
			if (!(hasPermission || (isEditAllowed && editOwn))) {
				return;
			}
			const blockEditInMinutes = settings.Message_AllowEditing_BlockEditInMinutes;
			if (blockEditInMinutes) {
				let msgTs;
				if (message.ts != null) {
					msgTs = moment(message.ts);
				}
				let currentTsDiff;
				if (msgTs != null) {
					currentTsDiff = moment().diff(msgTs, 'minutes');
				}
				return currentTsDiff < blockEditInMinutes;
			}
			return true;
		},
		order: 2,
		group: 'menu',
	});

	MessageAction.addButton({
		id: 'copy',
		icon: 'copy',
		label: 'Copy',
		classes: 'clipboard',
		context: ['message', 'message-mobile', 'threads'],
		action() {
			const { msg: { msg } } = messageArgs(this);
			navigator.clipboard.writeText(msg);
			toastr.success(TAPi18n.__('Copied'));
		},
		condition({ subscription }) {
			return !!subscription;
		},
		order: 3,
		group: 'menu',
	});

	MessageAction.addButton({
		id: 'delete-message',
		icon: 'trash',
		label: 'Delete',
		context: ['message', 'message-mobile', 'threads'],
		action() {
			const { msg } = messageArgs(this);
			getChatMessagesFrom(msg).confirmDeleteMsg(msg, true);//true -> "starred" attribute used as "deleted" for VO
		},
		condition({ msg: message, subscription }) {
			if (!subscription) {
				return false;
			}

			return canDeleteMessage({
				rid: message.rid,
				ts: message.ts,
				uid: message.u._id,
			});
		},
		order: 4,
		group: 'menu',
	});
});
