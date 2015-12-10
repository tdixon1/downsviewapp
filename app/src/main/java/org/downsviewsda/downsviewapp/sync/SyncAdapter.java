package org.downsviewsda.downsviewapp.sync;

import org.downsviewsda.downsviewapp.R;
import org.downsviewsda.downsviewapp.data.Contract;
import android.accounts.Account;
import android.accounts.AccountManager;
import android.content.AbstractThreadedSyncAdapter;
import android.content.ContentProviderClient;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.SyncRequest;
import android.content.SyncResult;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Vector;

/**
 * Created by Terrence on 9/27/2015.
 */
public class SyncAdapter   extends AbstractThreadedSyncAdapter {
    public final String LOG_TAG = SyncAdapter.class.getSimpleName();
    // Interval at which to sync with the weather, in seconds.
    // 60 seconds (1 minute) * 180 = 3 hours
    public static final int SYNC_INTERVAL = 60 * 180;
    public static final int SYNC_FLEXTIME = SYNC_INTERVAL/3;
    private static final String[] NOTIFY_DOWNSVIEW_NEWS_PROJECTION = new String[] {
            Contract.NewsEntry.COLUMN_NEWS_URL,
            Contract.NewsEntry.COLUMN_NEWS_TITLE,
            Contract.NewsEntry.COLUMN_NEWS_IMAGEURL,
            Contract.NewsEntry.COLUMN_NEWS_DATE_PUBLISHED,
            Contract.NewsEntry.COLUMN_NEWS_AUTHOR,
            Contract.NewsEntry.COLUMN_NEWS_CONTENT

    };

    // these indices must match the projection
    private static final int INDEX_NEWS_URL = 0;
    private static final int INDEX_NEWS_TITLE = 1;
    private static final int INDEX_NEWS_IMAGEURL = 2;
    private static final int INDEX_NEWS_DATE_PUBLISHED = 3;
    private static final int INDEX_NEWS_AUTHOR = 4;
    private static final int INDEX_NEWS_CONTENT = 5;

    private static final String[] NOTIFY_DOWNSVIEW_EVENTS_PROJECTION = new String[] {
            Contract.EventEntry.COLUMN_EVENT_IMAGEURL,
            Contract.EventEntry.COLUMN_EVENT_URL,
            Contract.EventEntry.COLUMN_EVENT_TITLE,
            Contract.EventEntry.COLUMN_EVENT_STARTDATE,
            Contract.EventEntry.COLUMN_EVENT_AUTHOR,
            Contract.EventEntry.COLUMN_EVENT_CONTENT,
            Contract.EventEntry.COLUMN_EVENT_ENDDATE,

    };

    private static final int INDEX_EVENT_IMAGEURL = 0;
    private static final int INDEX_EVENT_URL = 1;
    private static final int INDEX_EVENT_STARTTIME = 2;
    private static final int INDEX_EVENT_TITLE = 3;
    private static final int INDEX_EVENT_STARTDATE = 4;
    private static final int INDEX_EVENT_AUTHOR = 5;
    private static final int INDEX_EVENT_CONTENT = 6;
    private static final int INDEX_EVENT_ENDDATE = 7;
    private static final int INDEX_EVENT_ENDTIME = 8;

    private static final String[] NOTIFY_DOWNSVIEW_SERMONS_PROJECTION = new String[] {
            Contract.SermonEntry.COLUMN_SERMON_VIDEOURL,
            Contract.SermonEntry.COLUMN_SERMON_URL,
            Contract.SermonEntry.COLUMN_SERMON_TITLE,
            Contract.SermonEntry.COLUMN_SERMON_IMAGEURL,
            Contract.SermonEntry.COLUMN_SERMON_CONTENT,
            Contract.SermonEntry.COLUMN_SERMON_DATE,
            Contract.SermonEntry.COLUMN_SERMON_SPEAKER
    };

    private static final int INDEX_SERMON_VIDEOURL= 0;
    private static final int INDEX_SERMON_URL= 1;
    private static final int INDEX_SERMON_TITLE= 2;
    private static final int INDEX_SERMON_IMAGEURL= 3;
    private static final int INDEX_SERMON_CONTENT= 4;
    private static final int INDEX_SERMON_DATE= 5;
    private static final int INDEX_SERMON_SPEAKER= 6;

    private static final String[] NOTIFY_DOWNSVIEW_NEWSLETTER_PROJECTION = new String[] {
            Contract.NewsletterEntry.COLUMN_NEWSLETTER_URL,
            Contract.NewsletterEntry.COLUMN_NEWSLETTER_TITLE,
            Contract.NewsletterEntry.COLUMN_NEWSLETTER_IMAGEURL,
            Contract.NewsletterEntry.COLUMN_NEWSLETTER_CONTENT,
            Contract.NewsletterEntry.COLUMN_NEWSLETTER_DATE,
            Contract.NewsletterEntry.COLUMN_NEWSLETTER_WPID
    };

    private static final int INDEX_NEWSLETTER_URL= 1;
    private static final int INDEX_NEWSLETTER_TITLE= 2;
    private static final int INDEX_NEWSLETTER_IMAGEURL= 3;
    private static final int INDEX_NEWSLETTER_CONTENT= 4;
    private static final int INDEX_NEWSLETTER_DATE= 5;
    private static final int INDEX_NEWSLETTER_WPID= 6;

    private static final long DAY_IN_MILLIS = 1000 * 60 * 60 * 24;

    public SyncAdapter(Context context, boolean autoInitialize) {
        super(context, autoInitialize);
    }
    @Override
    public void onPerformSync(Account account, Bundle extras, String authority, ContentProviderClient provider, SyncResult syncResult) {
        Log.d(LOG_TAG, "Starting sync");

        //delete all news

        getJson("news", account, extras, authority, provider, syncResult);
        getJson("events", account, extras, authority, provider, syncResult);
        getJson("sermons", account, extras, authority, provider, syncResult);
        getJson("newsletters", account, extras, authority, provider, syncResult);
    }

    public void getJson(String type,Account account, Bundle extras, String authority, ContentProviderClient provider, SyncResult syncResult)
    {
        // These two need to be declared outside the try/catch
        // so that they can be closed in the finally block.
        HttpURLConnection urlConnection = null;
        BufferedReader reader = null;

        // Will contain the raw JSON response as a string.
        String jsonStr = null;

        try {
            // Construct the URL for the OpenWeatherMap query
            // Possible parameters are avaiable at OWM's forecast API page, at
            // http://openweathermap.org/API#forecast
            String FORECAST_BASE_URL = "";
            switch (type)
            {
                case "news":
                    FORECAST_BASE_URL =
                            "http://downsviewsda.org/api/news";
                    break;
                case "events":
                    FORECAST_BASE_URL =
                            "http://downsviewsda.org/api/events";
                    break;
                case "sermons":
                    FORECAST_BASE_URL =
                            "http://downsviewsda.org/api/sermons";
                    break;
                case "newsletters":
                    FORECAST_BASE_URL =
                            "http://downsviewsda.org/api/newsletters";
                    break;
            }

            Uri builtUri = Uri.parse(FORECAST_BASE_URL).buildUpon().build();
            URL url = new URL(builtUri.toString());

            // Create the request to DownsviewApi, and open the connection
            urlConnection = (HttpURLConnection) url.openConnection();
            urlConnection.setRequestMethod("GET");
            urlConnection.connect();

            // Read the input stream into a String
            InputStream inputStream = urlConnection.getInputStream();
            StringBuffer buffer = new StringBuffer();
            if (inputStream == null) {
                // Nothing to do.
                return;
            }

            reader = new BufferedReader(new InputStreamReader(inputStream));

            String line;
            while ((line = reader.readLine()) != null) {
                // Since it's JSON, adding a newline isn't necessary (it won't affect parsing)
                // But it does make debugging a *lot* easier if you print out the completed
                // buffer for debugging.
                buffer.append(line + "\n");
            }

            if (buffer.length() == 0) {
                // Stream was empty.  No point in parsing.
                return;
            }
            jsonStr = buffer.toString().replace("\t","");
            switch (type)
            {
                case "news":
                    getNewsDataFromJson(jsonStr);
                    break;
                case "events":
                    getEventDataFromJson(jsonStr);
                    break;
                case "sermons":
                    getSermonDataFromJson(jsonStr);
                    break;
                case "newsletters":
                    getNewslettterDataFromJson(jsonStr);
                    break;
            }
        } catch (IOException e) {
            Log.e(LOG_TAG, "Error ", e);
            // If the code didn't successfully get the weather data, there's no point in attempting
            // to parse it.
        } catch (JSONException e) {
            Log.e(LOG_TAG, e.getMessage(), e);
            e.printStackTrace();
        } finally {
            if (urlConnection != null) {
                urlConnection.disconnect();
            }
            if (reader != null) {
                try {
                    reader.close();
                } catch (final IOException e) {
                    Log.e(LOG_TAG, "Error closing stream", e);
                }
            }
        }


    }
    private void getNewsDataFromJson(String newsJsonStr) throws JSONException {
        // Now we have a String representing the complete forecast in JSON Format.
        // Fortunately parsing is easy:  constructor takes the JSON string and converts it
        // into an Object hierarchy for us.

        // These are the names of the JSON objects that need to be extracted.

        final String DAPI_AUTHOR = "post_author";
        final String DAPI_DATE = "post_date";
        final String DAPI_CONTENT = "post_content";
        final String DAPI_TITLE = "post_title";
        final String DAPI_URL = "guid";
        final String DAPI_IMGURL = "img";
        final String DAPI_WPID = "ID";

        // Downsview News.  Each news item info is an element of the "news" array.
        final String DAPI_NEWS = "news";

        try {
            JSONObject newsJson = new JSONObject(newsJsonStr);
            JSONArray newsArray = newsJson.getJSONArray(DAPI_NEWS);

            // Insert the new weather information into the database
            Vector<ContentValues> cVVector = new Vector<ContentValues>(newsArray.length());
            for(int i = 0; i < newsArray.length(); i++) {
                // These are the values that will be collected.
                String author;
                String content;
                long pubdate;
                String imgurl;
                String url;
                String title;
                int wpid;

                // Get the JSON object representing the day
                JSONObject newsItem = newsArray.getJSONObject(i);
                author = newsItem.getString(DAPI_AUTHOR);
                content = newsItem.getString(DAPI_CONTENT);
                pubdate = convertDateTimeStringToLong(newsItem.getString(DAPI_DATE));
                imgurl = newsItem.getString(DAPI_IMGURL);
                url = newsItem.getString(DAPI_URL);
                title = newsItem.getString(DAPI_TITLE);
                wpid = newsItem.getInt(DAPI_WPID);

                ContentValues newsValues = new ContentValues();
                newsValues.put(Contract.NewsEntry.COLUMN_NEWS_DATE_PUBLISHED, pubdate);
                newsValues.put(Contract.NewsEntry.COLUMN_NEWS_AUTHOR, author);
                newsValues.put(Contract.NewsEntry.COLUMN_NEWS_CONTENT, content);
                newsValues.put(Contract.NewsEntry.COLUMN_NEWS_IMAGEURL, imgurl);
                newsValues.put(Contract.NewsEntry.COLUMN_NEWS_TITLE, title);
                newsValues.put(Contract.NewsEntry.COLUMN_NEWS_URL, url);
                newsValues.put(Contract.NewsEntry.COLUMN_NEWS_WPID, wpid);

                cVVector.add(newsValues);
                Log.v(LOG_TAG,"added to collection" + newsItem.toString());

            }

            int inserted = 0;
            // add to database
            if ( cVVector.size() > 0 ) {
                ContentValues[] cvArray = new ContentValues[cVVector.size()];
                cVVector.toArray(cvArray);
                Log.v(LOG_TAG, "running bulk insert");
                try {
                    getContext().getContentResolver().bulkInsert(Contract.NewsEntry.CONTENT_URI, cvArray);
                } catch (Exception e)
                {
                    Log.e(LOG_TAG, e.getMessage());
                }

            }

            Log.d(LOG_TAG, "News Sync Complete. " + cVVector.size() + " Inserted");
        } catch (JSONException e) {
            Log.e(LOG_TAG, e.getMessage(), e);
            e.printStackTrace();
        }

    }

    private void getEventDataFromJson(String eventsJsonStr) throws JSONException {
        // Now we have a String representing the complete forecast in JSON Format.
        // Fortunately parsing is easy:  constructor takes the JSON string and converts it
        // into an Object hierarchy for us.

        // These are the names of the JSON objects that need to be extracted.

        final String DAPI_AUTHOR = "post_author";
        final String DAPI_STARTDATE = "startdate";
        final String DAPI_STARTTIME = "starttime";
        final String DAPI_ENDDATE = "enddate";
        final String DAPI_ENDTIME = "endtime";
        final String DAPI_CONTENT = "post_content";
        final String DAPI_TITLE = "post_title";
        final String DAPI_URL = "guid";
        final String DAPI_IMGURL = "img";
        final String DAPI_EVENTTYPE = "description";
        final String DAPI_WPID = "ID";

        // Downsview Events.  Each event item info is an element of the "events" array.
        final String DAPI_EVENTS = "events";

        try {
            JSONObject eventsJson = new JSONObject(eventsJsonStr);
            JSONArray eventArray = eventsJson.getJSONArray(DAPI_EVENTS);

            // Insert the new weather information into the database
            Vector<ContentValues> cVVector = new Vector<ContentValues>(eventArray.length());
            for(int i = 0; i < eventArray.length(); i++) {
                // These are the values that will be collected.
                String author;
                String content;
                long startdatetime;
                long enddatetime;
                String imgurl;
                String url;
                String title;
                String type;
                int wpid;

                // Get the JSON object representing the day
                JSONObject eventItem = eventArray.getJSONObject(i);
                author = eventItem.getString(DAPI_AUTHOR);
                content = eventItem.getString(DAPI_CONTENT);
                startdatetime = convertDateTimeStringToLong(eventItem.getString(DAPI_STARTDATE) + " " + (eventItem.getString(DAPI_STARTTIME) == "null" ? "00:00:00" : eventItem.getString(DAPI_STARTTIME)));
                enddatetime = convertDateTimeStringToLong(eventItem.getString(DAPI_ENDDATE) + " " + (eventItem.getString(DAPI_ENDTIME) == "null" ? "00:00:00" : eventItem.getString(DAPI_ENDTIME)));
                imgurl = eventItem.getString(DAPI_IMGURL);
                url = eventItem.getString(DAPI_URL);
                title = eventItem.getString(DAPI_TITLE);
                type = eventItem.getString(DAPI_EVENTTYPE);
                wpid = eventItem.getInt(DAPI_WPID);

                ContentValues eventValues = new ContentValues();
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_STARTDATE, startdatetime);
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_ENDDATE, enddatetime);
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_AUTHOR, author);
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_CONTENT, content);
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_IMAGEURL, imgurl);
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_TITLE, title);
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_URL, url);
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_TYPE, type);
                eventValues.put(Contract.EventEntry.COLUMN_EVENT_WPID, wpid);

                cVVector.add(eventValues);

            }

            int inserted = 0;
            // add to database
            if ( cVVector.size() > 0 ) {
                ContentValues[] cvArray = new ContentValues[cVVector.size()];
                cVVector.toArray(cvArray);
                getContext().getContentResolver().bulkInsert(Contract.EventEntry.CONTENT_URI, cvArray);
            }

            Log.d(LOG_TAG, "Event Sync Complete. " + cVVector.size() + " Inserted");
        } catch (JSONException e) {
            Log.e(LOG_TAG, e.getMessage(), e);
            e.printStackTrace();
        }

    }

    private void getSermonDataFromJson(String sermonJsonStr) throws JSONException {
        // Now we have a String representing the complete forecast in JSON Format.
        // Fortunately parsing is easy:  constructor takes the JSON string and converts it
        // into an Object hierarchy for us.

        // These are the names of the JSON objects that need to be extracted.

        //sermonJsonStr = sermonJsonStr.replaceAll("(\\r|\\n)", "");
        final String DAPI_SPEAKER = "speaker";
        final String DAPI_DATE = "post_date";
        final String DAPI_VIDEOURL= "url";
        final String DAPI_CONTENT = "post_content";
        final String DAPI_TITLE = "post_title";
        final String DAPI_URL = "guid";
        final String DAPI_IMGURL = "img";
        final String DAPI_WPID = "ID";


        // Downsview Sermons.  Each sermon item info is an element of the "sermons" array.
        final String DAPI_SERMONS = "sermons";

        try {
            JSONObject sermonJson = new JSONObject(sermonJsonStr);
            JSONArray sermonsArray = sermonJson.getJSONArray(DAPI_SERMONS);

            // Insert the new weather information into the database
            Vector<ContentValues> cVVector = new Vector<ContentValues>(sermonsArray.length());
            for(int i = 0; i < sermonsArray.length(); i++) {
                // These are the values that will be collected.
                String speaker;
                String content;
                long sermondate;
                String imgurl;
                String url;
                String title;
                String videourl;
                int wpid;

                // Get the JSON object representing the day
                JSONObject sermonItem = sermonsArray.getJSONObject(i);
                speaker = sermonItem.getString(DAPI_SPEAKER);
                content = sermonItem.getString(DAPI_CONTENT);
                sermondate = convertDateTimeStringToLong(sermonItem.getString(DAPI_DATE));
                imgurl = sermonItem.getString(DAPI_IMGURL);
                url = sermonItem.getString(DAPI_URL);
                title = sermonItem.getString(DAPI_TITLE);
                videourl = sermonItem.getString(DAPI_VIDEOURL);
                wpid = sermonItem.getInt(DAPI_WPID);

                ContentValues sermonValues = new ContentValues();
                sermonValues.put(Contract.SermonEntry.COLUMN_SERMON_DATE, sermondate);
                sermonValues.put(Contract.SermonEntry.COLUMN_SERMON_SPEAKER, speaker);
                sermonValues.put(Contract.SermonEntry.COLUMN_SERMON_CONTENT, content);
                sermonValues.put(Contract.SermonEntry.COLUMN_SERMON_IMAGEURL, imgurl);
                sermonValues.put(Contract.SermonEntry.COLUMN_SERMON_TITLE, title);
                sermonValues.put(Contract.SermonEntry.COLUMN_SERMON_URL, url);
                sermonValues.put(Contract.SermonEntry.COLUMN_SERMON_VIDEOURL, videourl);
                sermonValues.put(Contract.SermonEntry.COLUMN_SERMON_WPID, wpid);

                cVVector.add(sermonValues);

            }

            int inserted = 0;
            // add to database
            if ( cVVector.size() > 0 ) {
                ContentValues[] cvArray = new ContentValues[cVVector.size()];
                cVVector.toArray(cvArray);
                getContext().getContentResolver().bulkInsert(Contract.SermonEntry.CONTENT_URI, cvArray);
            }

            Log.d(LOG_TAG, "Sermon Sync Complete. " + cVVector.size() + " Inserted");
        } catch (JSONException e) {
            Log.e(LOG_TAG, e.getMessage(), e);
            e.printStackTrace();
        }

    }
    private void getNewslettterDataFromJson(String newsletterJsonStr) throws JSONException {
        // Now we have a String representing the complete forecast in JSON Format.
        // Fortunately parsing is easy:  constructor takes the JSON string and converts it
        // into an Object hierarchy for us.

        // These are the names of the JSON objects that need to be extracted.

        //sermonJsonStr = sermonJsonStr.replaceAll("(\\r|\\n)", "");

        final String DAPI_DATE = "post_date";
        final String DAPI_CONTENT = "post_content";
        final String DAPI_TITLE = "post_title";
        final String DAPI_URL = "guid";
        final String DAPI_IMGURL = "img";
        final String DAPI_WPID = "ID";


        // Downsview Sermons.  Each sermon item info is an element of the "sermons" array.
        final String DAPI_SERMONS = "newsletters";

        try {
            JSONObject newsletterJson = new JSONObject(newsletterJsonStr);
            JSONArray newsletterArray = newsletterJson.getJSONArray(DAPI_SERMONS);

            // Insert the new weather information into the database
            Vector<ContentValues> cVVector = new Vector<ContentValues>(newsletterArray.length());
            for(int i = 0; i < newsletterArray.length(); i++) {
                // These are the values that will be collected.

                String content;
                long date;
                String imgurl;
                String url;
                String title;
                int wpid;

                // Get the JSON object representing the day
                JSONObject nItem = newsletterArray.getJSONObject(i);
                content = nItem.getString(DAPI_CONTENT);
                date = convertDateTimeStringToLong(nItem.getString(DAPI_DATE));
                imgurl = nItem.getString(DAPI_IMGURL);
                url = nItem.getString(DAPI_URL);
                title = nItem.getString(DAPI_TITLE);
                wpid = nItem.getInt(DAPI_WPID);

                ContentValues nValues = new ContentValues();
                nValues.put(Contract.NewsletterEntry.COLUMN_NEWSLETTER_DATE, date);
                nValues.put(Contract.NewsletterEntry.COLUMN_NEWSLETTER_CONTENT, content);
                nValues.put(Contract.NewsletterEntry.COLUMN_NEWSLETTER_IMAGEURL, imgurl);
                nValues.put(Contract.NewsletterEntry.COLUMN_NEWSLETTER_TITLE, title);
                nValues.put(Contract.NewsletterEntry.COLUMN_NEWSLETTER_URL, url);
                nValues.put(Contract.NewsletterEntry.COLUMN_NEWSLETTER_WPID, wpid);

                cVVector.add(nValues);

            }

            int inserted = 0;
            // add to database
            if ( cVVector.size() > 0 ) {
                ContentValues[] cvArray = new ContentValues[cVVector.size()];
                cVVector.toArray(cvArray);
                getContext().getContentResolver().bulkInsert(Contract.NewsletterEntry.CONTENT_URI, cvArray);
            }

            Log.d(LOG_TAG, "Newsletter Sync Complete. " + cVVector.size() + " Inserted");
        } catch (JSONException e) {
            Log.e(LOG_TAG, e.getMessage(), e);
            e.printStackTrace();
        }

    }

    private long convertDateTimeStringToLong(String datetime)
    {
        DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        Date date = null;

        try {

            String s = ":";
            int counter = 0;
            for( int i=0; i<s.length(); i++ ) {
                if( s.charAt(i) == ':' ) {
                    counter++;
                }
            }
            if (counter < 2)
                datetime += ":00";
            date = dateFormat.parse(datetime);
            return date.getTime();

        } catch (ParseException e) {
            Log.e(LOG_TAG, e.getMessage(), e);
            e.printStackTrace();
        } catch (NullPointerException e) {
            Log.e(LOG_TAG, e.getMessage(), e);
            e.printStackTrace();
        }

        return -1;
    }
    /**
     * Helper method to schedule the sync adapter periodic execution
     */
    public static void configurePeriodicSync(Context context, int syncInterval, int flexTime) {
        Account account = getSyncAccount(context);
        String authority = context.getString(R.string.content_authority);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            // we can enable inexact timers in our periodic sync
            SyncRequest request = new SyncRequest.Builder().
                    syncPeriodic(syncInterval, flexTime).
                    setSyncAdapter(account, authority).
                    setExtras(new Bundle()).build();
            ContentResolver.requestSync(request);
        } else {
            ContentResolver.addPeriodicSync(account,
                    authority, new Bundle(), syncInterval);
        }
    }

    /**
     * Helper method to have the sync adapter sync immediately
     * @param context The context used to access the account service
     */
    public static void syncImmediately(Context context) {
        Bundle bundle = new Bundle();
        bundle.putBoolean(ContentResolver.SYNC_EXTRAS_EXPEDITED, true);
        bundle.putBoolean(ContentResolver.SYNC_EXTRAS_MANUAL, true);
        ContentResolver.requestSync(getSyncAccount(context),
                context.getString(R.string.content_authority), bundle);
    }

    /**
     * Helper method to get the fake account to be used with SyncAdapter, or make a new one
     * if the fake account doesn't exist yet.  If we make a new account, we call the
     * onAccountCreated method so we can initialize things.
     *
     * @param context The context used to access the account service
     * @return a fake account.
     */
    public static Account getSyncAccount(Context context) {
        // Get an instance of the Android account manager
        AccountManager accountManager =
                (AccountManager) context.getSystemService(Context.ACCOUNT_SERVICE);

        // Create the account type and default account
        Account newAccount = new Account(
                context.getString(R.string.app_name), context.getString(R.string.sync_account_type));

        // If the password doesn't exist, the account doesn't exist

        if ( null == accountManager.getPassword(newAccount) ) {

        /*
         * Add the account and account type, no password or user data
         * If successful, return the Account object, otherwise report an error.
         */
            if (!accountManager.addAccountExplicitly(newAccount, "", null)) {
                return null;
            }
            /*
             * If you don't set android:syncable="true" in
             * in your <provider> element in the manifest,
             * then call ContentResolver.setIsSyncable(account, AUTHORITY, 1)
             * here.
             */

            onAccountCreated(newAccount, context);
        }
        return newAccount;
    }

    private static void onAccountCreated(Account newAccount, Context context) {
        /*
         * Since we've created an account
         */
        SyncAdapter.configurePeriodicSync(context, SYNC_INTERVAL, SYNC_FLEXTIME);

        /*
         * Without calling setSyncAutomatically, our periodic sync will not be enabled.
         */
        ContentResolver.setSyncAutomatically(newAccount, context.getString(R.string.content_authority), true);

        /*
         * Finally, let's do a sync to get things started
         */
        syncImmediately(context);
    }

    public static void initializeSyncAdapter(Context context) {
        getSyncAccount(context);
    }
}
