package org.downsviewsda.downsviewapp.data;

import android.annotation.TargetApi;
import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteQueryBuilder;
import android.net.Uri;

/**
 * Created by Terrence on 9/27/2015.
 */
public class Provider  extends ContentProvider {
    // The URI Matcher used by this content provider.
    private static final UriMatcher sUriMatcher = buildUriMatcher();
    private DbHelper mOpenHelper;

    static final int NEWS = 100;
    static final int EVENTS = 200;
    static final int SERMONS = 300;
    static final int NEWSLETTER = 400;

    private static final SQLiteQueryBuilder sNewsQueryBuilder;
    private static final SQLiteQueryBuilder sEventQueryBuilder;
    private static final SQLiteQueryBuilder sSermonQueryBuilder;
    private static final SQLiteQueryBuilder sNewsletterQueryBuilder;

    static{
        sNewsQueryBuilder = new SQLiteQueryBuilder();
        sEventQueryBuilder = new SQLiteQueryBuilder();
        sSermonQueryBuilder = new SQLiteQueryBuilder();
        sNewsletterQueryBuilder = new SQLiteQueryBuilder();

        sNewsQueryBuilder.setTables(Contract.NewsEntry.TABLE_NAME);
        sEventQueryBuilder.setTables(Contract.EventEntry.TABLE_NAME);
        sSermonQueryBuilder.setTables(Contract.SermonEntry.TABLE_NAME);
        sNewsletterQueryBuilder.setTables(Contract.NewsletterEntry.TABLE_NAME);
    }

    private Cursor getNews(Uri uri, String[] projection,String selection, String[] selectionArgs, String sortOrder)
    {
        return sNewsQueryBuilder.query(mOpenHelper.getReadableDatabase(),
                projection,
                selection,
                selectionArgs,
                null,
                null,
                sortOrder
        );
    }
    private Cursor getEvents(Uri uri, String[] projection,String selection, String[] selectionArgs, String sortOrder)
    {
        return sEventQueryBuilder.query(mOpenHelper.getReadableDatabase(),
                projection,
                selection,
                selectionArgs,
                null,
                null,
                sortOrder
        );
    }
    private Cursor getSermons(Uri uri, String[] projection,String selection, String[] selectionArgs, String sortOrder)
    {

        return sSermonQueryBuilder.query(mOpenHelper.getReadableDatabase(),
                projection,
                selection,
                selectionArgs,
                null,
                null,
                sortOrder
        );
    }

    private Cursor getNewsletter(Uri uri, String[] projection,String selection, String[] selectionArgs, String sortOrder)
    {

        return sNewsletterQueryBuilder.query(mOpenHelper.getReadableDatabase(),
                projection,
                selection,
                selectionArgs,
                null,
                null,
                sortOrder
        );
    }
    @Override
    public boolean onCreate() {
        mOpenHelper = new DbHelper(getContext());
        return true;
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        // Here's the switch statement that, given a URI, will determine what kind of request it is,
        // and query the database accordingly.
        Cursor retCursor;
        switch (sUriMatcher.match(uri)) {
            // "weather/*/*"
            case NEWS:
            {
                retCursor = getNews(uri, projection, selection, selectionArgs,sortOrder);
                break;
            }
            // "weather/*"
            case EVENTS: {
                retCursor = getEvents(uri, projection, selection, selectionArgs, sortOrder);
                break;
            }
            // "weather"
            case SERMONS: {
                retCursor = getSermons(uri,projection,selection, selectionArgs,sortOrder);
                break;
            }
            case NEWSLETTER:{
                retCursor = getNewsletter(uri,projection,selection, selectionArgs,sortOrder);
                break;
            }
            default:
                throw new UnsupportedOperationException("Unknown uri: " + uri);
        }
        retCursor.setNotificationUri(getContext().getContentResolver(), uri);
        return retCursor;
    }

    @Override
    public String getType(Uri uri) {
        // Use the Uri Matcher to determine what kind of URI this is.
        final int match = sUriMatcher.match(uri);

        switch (match) {
            // Student: Uncomment and fill out these two cases
            case NEWS:
                return Contract.NewsEntry.CONTENT_ITEM_TYPE;
            case EVENTS:
                return Contract.EventEntry.CONTENT_TYPE;
            case SERMONS:
                return Contract.SermonEntry.CONTENT_TYPE;
            case NEWSLETTER:
                return Contract.NewsletterEntry.CONTENT_TYPE;
            default:
                throw new UnsupportedOperationException("Unknown uri: " + uri);
        }
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        final SQLiteDatabase db = mOpenHelper.getWritableDatabase();
        final int match = sUriMatcher.match(uri);
        Uri returnUri;

        switch (match) {
            case NEWS: {
                normalizeDate(values);
                long _id = db.insert(Contract.NewsEntry.TABLE_NAME, null, values);
                if ( _id > 0 )
                    returnUri = Contract.NewsEntry.buildNewsUri(_id);
                else
                    throw new android.database.SQLException("Failed to insert row into " + uri);
                break;
            }
            case EVENTS: {
                normalizeDate(values);
                long _id = db.insert(Contract.EventEntry.TABLE_NAME, null, values);
                if ( _id > 0 )
                    returnUri = Contract.EventEntry.buildEventUri(_id);
                else
                    throw new android.database.SQLException("Failed to insert row into " + uri);
                break;
            }
            case SERMONS: {
                normalizeDate(values);
                long _id = db.insert(Contract.SermonEntry.TABLE_NAME, null, values);
                if ( _id > 0 )
                    returnUri = Contract.SermonEntry.buildSermonUri(_id);
                else
                    throw new android.database.SQLException("Failed to insert row into " + uri);
                break;
            }
            case NEWSLETTER: {
                normalizeDate(values);
                long _id = db.insert(Contract.NewsletterEntry.TABLE_NAME, null, values);
                if ( _id > 0 )
                    returnUri = Contract.NewsletterEntry.buildNewsletterUri(_id);
                else
                    throw new android.database.SQLException("Failed to insert row into " + uri);
                break;
            }
            default:
                throw new UnsupportedOperationException("Unknown uri: " + uri);
        }
        getContext().getContentResolver().notifyChange(uri, null);
        return returnUri;
    }

    private void normalizeDate(ContentValues values) {
        // normalize the date value
        if (values.containsKey(Contract.NewsEntry.COLUMN_NEWS_DATE_PUBLISHED)) {
            long dateValue = values.getAsLong(Contract.NewsEntry.COLUMN_NEWS_DATE_PUBLISHED);
            values.put(Contract.NewsEntry.COLUMN_NEWS_DATE_PUBLISHED, Contract.normalizeDate(dateValue));
        }

        if (values.containsKey(Contract.EventEntry.COLUMN_EVENT_ENDDATE)) {
            long dateValue = values.getAsLong(Contract.EventEntry.COLUMN_EVENT_ENDDATE);
            values.put(Contract.EventEntry.COLUMN_EVENT_ENDDATE, Contract.normalizeDate(dateValue));
        }

        if (values.containsKey(Contract.EventEntry.COLUMN_EVENT_STARTDATE)) {
            long dateValue = values.getAsLong(Contract.EventEntry.COLUMN_EVENT_STARTDATE);
            values.put(Contract.EventEntry.COLUMN_EVENT_STARTDATE, Contract.normalizeDate(dateValue));
        }

        if (values.containsKey(Contract.SermonEntry.COLUMN_SERMON_DATE)) {
            long dateValue = values.getAsLong(Contract.SermonEntry.COLUMN_SERMON_DATE);
            values.put(Contract.SermonEntry.COLUMN_SERMON_DATE, Contract.normalizeDate(dateValue));
        }
        if (values.containsKey(Contract.NewsletterEntry.COLUMN_NEWSLETTER_DATE)) {
            long dateValue = values.getAsLong(Contract.NewsletterEntry.COLUMN_NEWSLETTER_DATE);
            values.put(Contract.NewsletterEntry.COLUMN_NEWSLETTER_DATE, Contract.normalizeDate(dateValue));
        }
    }
    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        final SQLiteDatabase db = mOpenHelper.getWritableDatabase();
        final int match = sUriMatcher.match(uri);
        int rowsDeleted;
        // this makes delete all rows return the number of rows deleted
        if ( null == selection ) selection = "1";
        switch (match) {
            case NEWS:
                rowsDeleted = db.delete(
                        Contract.NewsEntry.TABLE_NAME, selection, selectionArgs);
                break;
            case EVENTS:
                rowsDeleted = db.delete(
                        Contract.EventEntry.TABLE_NAME, selection, selectionArgs);
                break;
            case SERMONS:
                rowsDeleted = db.delete(
                        Contract.SermonEntry.TABLE_NAME, selection, selectionArgs);
                break;
            case NEWSLETTER:
                rowsDeleted = db.delete(
                        Contract.NewsletterEntry.TABLE_NAME, selection, selectionArgs);
                break;
            default:
                throw new UnsupportedOperationException("Unknown uri: " + uri);
        }
        // Because a null deletes all rows
        if (rowsDeleted != 0) {
            getContext().getContentResolver().notifyChange(uri, null);
        }
        return rowsDeleted;
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
        final SQLiteDatabase db = mOpenHelper.getWritableDatabase();
        final int match = sUriMatcher.match(uri);
        int rowsUpdated;

        switch (match) {
            case NEWS:
                normalizeDate(values);
                rowsUpdated = db.update(Contract.NewsEntry.TABLE_NAME, values, selection,
                        selectionArgs);
                break;
            case EVENTS:
                rowsUpdated = db.update(Contract.EventEntry.TABLE_NAME, values, selection,
                        selectionArgs);
                break;
            case SERMONS:
                rowsUpdated = db.update(Contract.SermonEntry.TABLE_NAME, values, selection,
                        selectionArgs);
                break;
            case NEWSLETTER:
                rowsUpdated = db.update(Contract.NewsletterEntry.TABLE_NAME, values, selection,
                        selectionArgs);
                break;
            default:
                throw new UnsupportedOperationException("Unknown uri: " + uri);
        }
        if (rowsUpdated != 0) {
            getContext().getContentResolver().notifyChange(uri, null);
        }
        return rowsUpdated;
    }
    public int bulkInsert(Uri uri, ContentValues[] values) {
        if (mOpenHelper == null)
            mOpenHelper = new DbHelper(getContext());
        final SQLiteDatabase db = mOpenHelper.getWritableDatabase();
        final int match = sUriMatcher.match(uri);
        switch (match) {
            case NEWS:
                db.beginTransaction();
                int newsReturnCount = 0;
                try {
                    for (ContentValues value : values) {
                        normalizeDate(value);
                        long _id = db.insert(Contract.NewsEntry.TABLE_NAME, null, value);
                        if (_id != -1) {
                            newsReturnCount++;
                        }
                    }
                    db.setTransactionSuccessful();
                } finally {
                    db.endTransaction();
                }
                getContext().getContentResolver().notifyChange(uri, null);
                return newsReturnCount;
            case EVENTS:
                db.beginTransaction();
                int eventsReturnCount = 0;
                try {
                    for (ContentValues value : values) {
                        normalizeDate(value);
                        long _id = db.insert(Contract.EventEntry.TABLE_NAME, null, value);
                        if (_id != -1) {
                            eventsReturnCount++;
                        }
                    }
                    db.setTransactionSuccessful();
                } finally {
                    db.endTransaction();
                }
                getContext().getContentResolver().notifyChange(uri, null);
                return eventsReturnCount;
            case SERMONS:
                db.beginTransaction();
                int sermonReturnCount = 0;
                try {
                    for (ContentValues value : values) {
                        normalizeDate(value);
                        long _id = db.insert(Contract.SermonEntry.TABLE_NAME, null, value);
                        if (_id != -1) {
                            sermonReturnCount++;
                        }
                    }
                    db.setTransactionSuccessful();
                } finally {
                    db.endTransaction();
                }
                getContext().getContentResolver().notifyChange(uri, null);
                return sermonReturnCount;
            case NEWSLETTER:
                db.beginTransaction();
                int letterReturnCount = 0;
                try {
                    for (ContentValues value : values) {
                        normalizeDate(value);
                        long _id = db.insert(Contract.NewsletterEntry.TABLE_NAME, null, value);
                        if (_id != -1) {
                            letterReturnCount++;
                        }
                    }
                    db.setTransactionSuccessful();
                } finally {
                    db.endTransaction();
                }
                getContext().getContentResolver().notifyChange(uri, null);
                return letterReturnCount;
            default:
                return super.bulkInsert(uri, values);
        }
    }
    static UriMatcher buildUriMatcher() {
        // I know what you're thinking.  Why create a UriMatcher when you can use regular
        // expressions instead?  Because you're not crazy, that's why.

        // All paths added to the UriMatcher have a corresponding code to return when a match is
        // found.  The code passed into the constructor represents the code to return for the root
        // URI.  It's common to use NO_MATCH as the code for this case.
        final UriMatcher matcher = new UriMatcher(UriMatcher.NO_MATCH);
        final String authority = Contract.CONTENT_AUTHORITY;

        // For each type of URI you want to add, create a corresponding code.
        matcher.addURI(authority, Contract.PATH_NEWS, NEWS);
        matcher.addURI(authority, Contract.PATH_EVENT, EVENTS);
        matcher.addURI(authority, Contract.PATH_SERMON, SERMONS);
        matcher.addURI(authority, Contract.PATH_NEWSLETTER, NEWSLETTER);
        return matcher;
    }
    // You do not need to call this method. This is a method specifically to assist the testing
    // framework in running smoothly. You can read more at:
    // http://developer.android.com/reference/android/content/ContentProvider.html#shutdown()
    @Override
    @TargetApi(11)
    public void shutdown() {
        mOpenHelper.close();
        super.shutdown();
    }
}