/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of Weave.
 *
 * The Initial Developer of Weave is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2015
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

package weavejs.net
{
	import weavejs.api.core.ILinkableObject;
	import weavejs.util.JS;
	import weavejs.util.StandardLib;
	import weavejs.util.WeavePromise;

	public class JsonCache implements ILinkableObject
	{
		public static function buildURL(base:String, params:Object):String
		{
			var paramsStr:String = '';
			for (var key:String in params)
				paramsStr += (paramsStr ? '&' : '?') + encodeURIComponent(key) + '=' + encodeURIComponent(params[key]);
			return base + paramsStr;
		}
		
		/**
		 * @param requestHeaders Optionally set this to an Object mapping header names to values.
		 */
		public function JsonCache(requestHeaders:Object = null)
		{
			if (!requestHeaders)
				requestHeaders = {"Accept": "application/json"};
			this.requestHeaders = requestHeaders;
		}
		
		private var _requestHeaders:Object = null;
		
		private var cache:Object = {};
		
		public function clearCache():void
		{
			for each (var entry:CacheEntry in cache)
				entry.dispose();
			cache = {};
			Weave.getCallbacks(this).triggerCallbacks();
		}
		
		/**
		 * @param url The URL to get JSON data
		 * @return The cached Object.
		 */
		public function getJsonObject(url:String):Object
		{
			return getCacheEntry(url).result;
		}
		
		public function getJsonPromise(relevantContext:Object, url:String):WeavePromise
		{
			return new WeavePromise(relevantContext, function(resolve:Function, reject:Function):void {
				getCacheEntry(url).addHandler(resolve, reject);
			});
		}
		
		private function getCacheEntry(url:String):CacheEntry
		{
			var entry:CacheEntry = cache[url];
			if (!entry)
			{
				var request:URLRequest = new URLRequest(url);
				request.requestHeaders = requestHeaders;
				entry = new CacheEntry(this, request);
				cache[url] = entry;
			}
			return entry;
		}
		
		public static function parseJSON(json:String):Object
		{
			try
			{
				return JSON.parse(json);
			}
			catch (e:Error)
			{
				JS.error("Unable to parse JSON result");
				trace(json);
			}
			return null;
		}
	}
}

import weavejs.net.JsonCache;
import weavejs.net.URLRequestUtils;
import weavejs.util.JS;
import weavejs.util.StandardLib;

internal class CacheEntry
{
	public function CacheEntry(owner:JsonCache, request:URLRequest)
	{
		this.owner = owner;
		this.request = request;
		addAsyncResponder(
			WeaveAPI.URLRequestUtils.getURL(owner, request, URLRequestUtils.DATA_FORMAT_TEXT),
			handleResponse,
			handleResponse
		);
	}
	
	public var owner:JsonCache;
	public var request:URLRequest;
	public var handlers:Array = [];
	public var result:Object = {};
	public var success:Boolean = false;
	
	private function handleResponse(event:Event, token:Object = null):void
	{
		// stop if disposed
		if (!owner)
			return;
		
		var response:Object;
		if (event is ResultEvent)
		{
			success = true;
			response = (event as ResultEvent).result;
			response = JsonCache.parseJSON(response as String);
			// avoid storing a null value
			if (response != null)
				result = response;
		}
		else
		{
			success = false;
			response = (event as FaultEvent).fault.content;
			if (response)
				JS.error("Request failed: " + request.url + "\n" + StandardLib.trim(String(response)));
			else
				JS.error(event);
		}
		
		// call handlers
		while (handlers.length)
		{
			var obj:Object = handlers.shift();
			if (event is ResultEvent && obj[RESULT] is Function)
				(obj[RESULT] as Function).apply(null, [result]);
			if (event is FaultEvent && obj[FAULT] is Function)
				(obj[FAULT] as Function).apply(null, [result]);
		}
		// stop further handlers from being added
		handlers = null;
	}
	
	private static const RESULT:int = 0; // index of resultHandler in handlers item
	private static const FAULT:int = 1; // index of faultHandler in handlers item
	
	public function addHandler(resultHandler:Function, faultHandler:Function):void
	{
		if (handlers)
		{
			handlers.push([resultHandler, faultHandler]);
		}
		else
		{
			WeaveAPI.ProgressIndicator.addTask(doLater, owner, "Retrieving JSON data from cache");
			function doLater():void
			{
				WeaveAPI.ProgressIndicator.removeTask(doLater);
				if (objectWasDisposed(owner))
					return;
				if (success && resultHandler is Function)
					resultHandler(result);
				if (!success && faultHandler is Function)
					faultHandler(result);
			}
			WeaveAPI.StageUtils.callLater(null, doLater);
		}
	}
	
	public function dispose():void
	{
		owner = null;
		handlers = null;
	}
}