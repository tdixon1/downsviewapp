package org.downsviewsda.downsviewapp.data;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import org.downsviewsda.downsviewapp.data.Contract.NewsEntry;
import org.downsviewsda.downsviewapp.data.Contract.SermonEntry;
import org.downsviewsda.downsviewapp.data.Contract.NewsletterEntry;
import org.downsviewsda.downsviewapp.data.Contract.EventEntry;

/**
 * Created by Terrence on 9/27/2015.
 */
public class DbHelper  extends SQLiteOpenHelper {
    // If you change the database schema, you must increment the database version.
    private static final int DATABASE_VERSION = 2;

    static final String DATABASE_NAME = "downsview.db";

    public DbHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }
    @Override
    public void onCreate(SQLiteDatabase db) {
        // Create a table to hold news.
        final String SQL_CREATE_NEWS_TABLE = "CREATE TABLE " + NewsEntry.TABLE_NAME + " (" +
                // Why AutoIncrement here, and not above?
                // Unique keys will be auto-generated in either case.  But for weather
                // forecasting, it's reasonable to assume the user will want information
                // for a certain date and all dates *following*, so the forecast data
                // should be sorted accordingly.

                NewsEntry._ID + " INTEGER PRIMARY KEY AUTOINCREMENT," +
                // the ID of the location entry associated with this weather data
                NewsEntry.COLUMN_NEWS_WPID + " INTEGER NOT NULL, " +
                NewsEntry.COLUMN_NEWS_AUTHOR + " TEXT NOT NULL, " +
                NewsEntry.COLUMN_NEWS_CONTENT + " TEXT NOT NULL, " +
                NewsEntry.COLUMN_NEWS_DATE_PUBLISHED + " INTEGER NOT NULL, " +
                NewsEntry.COLUMN_NEWS_IMAGEURL + " TEXT NOT NULL," +
                NewsEntry.COLUMN_NEWS_TITLE + " TEXT NOT NULL, " +
                NewsEntry.COLUMN_NEWS_URL + " TEXT NOT NULL, " +
                // To assure the application have just one event entry
                // it's created a UNIQUE constraint with REPLACE strategy
                " UNIQUE (" + NewsEntry.COLUMN_NEWS_WPID + ") ON CONFLICT REPLACE);";

        final String SQL_CREATE_EVENT_TABLE = "CREATE TABLE " + EventEntry.TABLE_NAME + " (" +
                // Why AutoIncrement here, and not above?
                // Unique keys will be auto-generated in either case.  But for weather
                // forecasting, it's reasonable to assume the user will want information
                // for a certain date and all dates *following*, so the forecast data
                // should be sorted accordingly.
                EventEntry._ID + " INTEGER PRIMARY KEY AUTOINCREMENT," +
                // the ID of the location entry associated with this weather data
                EventEntry.COLUMN_EVENT_WPID + " INTEGER NOT NULL, " +
                EventEntry.COLUMN_EVENT_AUTHOR + " TEXT NOT NULL, " +
                EventEntry.COLUMN_EVENT_CONTENT + " TEXT NOT NULL, " +
                EventEntry.COLUMN_EVENT_ENDDATE + " INTEGER NULL, " +
                EventEntry.COLUMN_EVENT_STARTDATE + " INTEGER NOT NULL, " +
                EventEntry.COLUMN_EVENT_IMAGEURL + " TEXT NOT NULL, " +
                EventEntry.COLUMN_EVENT_TITLE + " TEXT NOT NULL, " +
                EventEntry.COLUMN_EVENT_URL + " TEXT NOT NULL, " +
                EventEntry.COLUMN_EVENT_TYPE + " TEXT NOT NULL, " +
                // To assure the application have just one event entry
                // it's created a UNIQUE constraint with REPLACE strategy
                " UNIQUE (" + EventEntry.COLUMN_EVENT_WPID + ") ON CONFLICT REPLACE);";

        final String SQL_CREATE_SERMNON_TABLE = "CREATE TABLE " + SermonEntry.TABLE_NAME + " (" +
                // Why AutoIncrement here, and not above?
                // Unique keys will be auto-generated in either case.  But for weather
                // forecasting, it's reasonable to assume the user will want information
                // for a certain date and all dates *following*, so the forecast data
                // should be sorted accordingly.
                SermonEntry._ID + " INTEGER PRIMARY KEY AUTOINCREMENT," +
                // the ID of the location entry associated with this weather data
                SermonEntry.COLUMN_SERMON_WPID + " INTEGER NOT NULL, " +
                SermonEntry.COLUMN_SERMON_SPEAKER + " TEXT NOT NULL, " +
                SermonEntry.COLUMN_SERMON_CONTENT + " TEXT NOT NULL, " +
                SermonEntry.COLUMN_SERMON_DATE + " INTEGER NOT NULL, " +
                SermonEntry.COLUMN_SERMON_IMAGEURL + " TEXT NOT NULL," +
                SermonEntry.COLUMN_SERMON_TITLE + " TEXT NOT NULL, " +
                SermonEntry.COLUMN_SERMON_URL + " TEXT NOT NULL, " +
                SermonEntry.COLUMN_SERMON_VIDEOURL + " TEXT NOT NULL, " +
                // To assure the application have just one event entry
                // it's created a UNIQUE constraint with REPLACE strategy
                " UNIQUE (" + SermonEntry.COLUMN_SERMON_WPID + ") ON CONFLICT REPLACE);";

        final String SQL_CREATE_NEWSLETTER_TABLE = "CREATE TABLE " + Contract.NewsletterEntry.TABLE_NAME + " (" +
                // Why AutoIncrement here, and not above?
                // Unique keys will be auto-generated in either case.  But for weather
                // forecasting, it's reasonable to assume the user will want information
                // for a certain date and all dates *following*, so the forecast data
                // should be sorted accordingly.
                NewsletterEntry._ID + " INTEGER PRIMARY KEY AUTOINCREMENT," +
                // the ID of the location entry associated with this weather data
                NewsletterEntry.COLUMN_NEWSLETTER_WPID + " INTEGER NOT NULL, " +
                NewsletterEntry.COLUMN_NEWSLETTER_CONTENT + " TEXT NOT NULL, " +
                NewsletterEntry.COLUMN_NEWSLETTER_DATE + " INTEGER NOT NULL, " +
                NewsletterEntry.COLUMN_NEWSLETTER_IMAGEURL + " TEXT NOT NULL," +
                NewsletterEntry.COLUMN_NEWSLETTER_TITLE + " TEXT NOT NULL, " +
                NewsletterEntry.COLUMN_NEWSLETTER_URL + " TEXT NOT NULL, " +
                // To assure the application have just one event entry
                // it's created a UNIQUE constraint with REPLACE strategy
                " UNIQUE (" + NewsletterEntry.COLUMN_NEWSLETTER_WPID + ") ON CONFLICT REPLACE);";

        db.execSQL(SQL_CREATE_EVENT_TABLE);
        db.execSQL(SQL_CREATE_NEWS_TABLE);
        db.execSQL(SQL_CREATE_SERMNON_TABLE);
        db.execSQL(SQL_CREATE_NEWSLETTER_TABLE);

    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        db.execSQL("DROP TABLE IF EXISTS " + EventEntry.TABLE_NAME);
        db.execSQL("DROP TABLE IF EXISTS " + NewsEntry.TABLE_NAME);
        db.execSQL("DROP TABLE IF EXISTS " +SermonEntry.TABLE_NAME);
        db.execSQL("DROP TABLE IF EXISTS " +NewsletterEntry.TABLE_NAME);
        onCreate(db);
    }
}
