package org.downsviewsda.downsviewapp.data;

import android.content.ContentResolver;
import android.content.ContentUris;
import android.net.Uri;
import android.provider.BaseColumns;
import android.text.format.Time;

import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * Created by Terrence on 9/27/2015.
 */
public class Contract {
    // The "Content authority" is a name for the entire content provider, similar to the
    // relationship between a domain name and its website.  A convenient string to use for the
    // content authority is the package name for the app, which is guaranteed to be unique on the
    // device.
    public static final String CONTENT_AUTHORITY = "org.downsviewsda.downsviewapp";

    // Use CONTENT_AUTHORITY to create the base of all URI's which apps will use to contact
    // the content provider.
    public static final Uri BASE_CONTENT_URI = Uri.parse("content://" + CONTENT_AUTHORITY);

    // Possible paths (appended to base content URI for possible URI's)
    // For instance, content://org.downsview.downsviewapp/news/ is a valid path for
    // looking at news data. content://org.downsview.downsviewapp/givemeroot/ will fail,
    // as the ContentProvider hasn't been given any information on what to do with "givemeroot".
    // At least, let's hope not.  Don't be that dev, reader.  Don't be that dev.
    public static final String PATH_NEWS = "news";
    public static final String PATH_EVENT = "event";
    public static final String PATH_SERMON = "sermon";
    public static final String PATH_NEWSLETTER = "newsletter";

    // Format used for storing dates in the database.  ALso used for converting those strings
    // back into date objects for comparison/processing.
    public static final String DATE_FORMAT = "yyyyMMdd";
    /**
     * Converts unix time to a string representation, used for easy comparison and database lookup.
     * @param date The input date
     * @return a DB-friendly representation of the date, using the format defined in DATE_FORMAT.
     */
    public static String getDbDateString(Date date){
        SimpleDateFormat sdf = new SimpleDateFormat(DATE_FORMAT);
        return sdf.format(date);
    }
    // To make it easy to query for the exact date, we normalize all dates that go into
    // the database to the start of the the Julian day at UTC.
    public static long normalizeDate(long startDate) {
        // normalize the start date to the beginning of the (UTC) day
        Time time = new Time();
        time.set(startDate);
        int julianDay = Time.getJulianDay(startDate, time.gmtoff);
        return time.setJulianDay(julianDay);
    }

    /* Inner class that defines the table contents of the news table */
    public static final class NewsEntry implements BaseColumns {
        public static final Uri CONTENT_URI =
                BASE_CONTENT_URI.buildUpon().appendPath(PATH_NEWS).build();

        public static final String CONTENT_TYPE =
                ContentResolver.CURSOR_DIR_BASE_TYPE + "/" + CONTENT_AUTHORITY + "/" + PATH_NEWS;
        public static final String CONTENT_ITEM_TYPE =
                ContentResolver.CURSOR_ITEM_BASE_TYPE + "/" + CONTENT_AUTHORITY + "/" + PATH_NEWS;

        // Table name
        public static final String TABLE_NAME = "news";

        public static final String COLUMN_NEWS_WPID = "wpid";
        public static final String COLUMN_NEWS_TITLE = "title";
        public static final String COLUMN_NEWS_CONTENT = "content";
        public static final String COLUMN_NEWS_AUTHOR = "author";
        public static final String COLUMN_NEWS_DATE_PUBLISHED = "pubdate";
        public static final String COLUMN_NEWS_IMAGEURL = "image";
        public static final String COLUMN_NEWS_URL = "url";

        public static Uri buildNewsUri(long id) {
            return ContentUris.withAppendedId(CONTENT_URI, id);
        }
    }

    /* Inner class that defines the table contents of the events table */
    public static final class EventEntry implements BaseColumns {
        public static final Uri CONTENT_URI =
                BASE_CONTENT_URI.buildUpon().appendPath(PATH_EVENT).build();

        public static final String CONTENT_TYPE =
                ContentResolver.CURSOR_DIR_BASE_TYPE + "/" + CONTENT_AUTHORITY + "/" + PATH_EVENT;
        public static final String CONTENT_ITEM_TYPE =
                ContentResolver.CURSOR_ITEM_BASE_TYPE + "/" + CONTENT_AUTHORITY + "/" + PATH_EVENT;

        // Table name
        public static final String TABLE_NAME = "event";

        public static final String COLUMN_EVENT_WPID = "wpid";
        public static final String COLUMN_EVENT_TITLE = "title";
        public static final String COLUMN_EVENT_CONTENT = "content";
        public static final String COLUMN_EVENT_AUTHOR = "author";
        public static final String COLUMN_EVENT_STARTDATE = "startdate";
        public static final String COLUMN_EVENT_ENDDATE = "enddate";
        public static final String COLUMN_EVENT_IMAGEURL = "image";
        public static final String COLUMN_EVENT_URL = "url";
        public static final String COLUMN_EVENT_TYPE = "type";

        public static Uri buildEventUri(long id) {
            return ContentUris.withAppendedId(CONTENT_URI, id);
        }

    }

    /* Inner class that defines the table contents of the events table */
    public static final class SermonEntry implements BaseColumns {
        public static final Uri CONTENT_URI =
                BASE_CONTENT_URI.buildUpon().appendPath(PATH_SERMON).build();

        public static final String CONTENT_TYPE =
                ContentResolver.CURSOR_DIR_BASE_TYPE + "/" + CONTENT_AUTHORITY + "/" + PATH_SERMON;
        public static final String CONTENT_ITEM_TYPE =
                ContentResolver.CURSOR_ITEM_BASE_TYPE + "/" + CONTENT_AUTHORITY + "/" + PATH_SERMON;

        // Table name
        public static final String TABLE_NAME = "sermon";

        public static final String COLUMN_SERMON_WPID = "wpid";
        public static final String COLUMN_SERMON_TITLE = "title";
        public static final String COLUMN_SERMON_CONTENT = "content";
        public static final String COLUMN_SERMON_SPEAKER = "speaker";
        public static final String COLUMN_SERMON_DATE = "pubdate";
        public static final String COLUMN_SERMON_VIDEOURL = "videourl";
        public static final String COLUMN_SERMON_IMAGEURL = "image";
        public static final String COLUMN_SERMON_URL = "url";

        public static Uri buildSermonUri(long id) {
            return ContentUris.withAppendedId(CONTENT_URI, id);
        }
    }

    public static final class NewsletterEntry implements BaseColumns {
        public static final Uri CONTENT_URI =
                BASE_CONTENT_URI.buildUpon().appendPath(PATH_NEWSLETTER).build();

        public static final String CONTENT_TYPE =
                ContentResolver.CURSOR_DIR_BASE_TYPE + "/" + CONTENT_AUTHORITY + "/" + PATH_NEWSLETTER;
        public static final String CONTENT_ITEM_TYPE =
                ContentResolver.CURSOR_ITEM_BASE_TYPE + "/" + CONTENT_AUTHORITY + "/" + PATH_NEWSLETTER;

        // Table name
        public static final String TABLE_NAME = "newsletter";

        public static final String COLUMN_NEWSLETTER_WPID = "wpid";
        public static final String COLUMN_NEWSLETTER_TITLE = "title";
        public static final String COLUMN_NEWSLETTER_CONTENT = "content";
        public static final String COLUMN_NEWSLETTER_DATE = "pubdate";
        public static final String COLUMN_NEWSLETTER_IMAGEURL = "image";
        public static final String COLUMN_NEWSLETTER_URL = "url";

        public static Uri buildNewsletterUri(long id) {
            return ContentUris.withAppendedId(CONTENT_URI, id);
        }
    }
}
