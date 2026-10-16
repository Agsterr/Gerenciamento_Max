package com.max.salao.release;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** Um APK publicado fora da loja. O arquivo fica em {@code app.releases.storage-path}. */
@Getter
@Setter
@Entity
@Table(name = "app_release")
public class AppRelease {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** {@link MobileApp#id()} */
    @Column(nullable = false, updatable = false)
    private String app;

    @Column(nullable = false)
    private String versionName;

    @Column(nullable = false)
    private int versionCode;

    @Column(nullable = false)
    private String fileName;

    @Column(nullable = false)
    private long fileSizeBytes;

    @Column(nullable = false)
    private String sha256;

    private String releaseNotes;

    @Column(nullable = false)
    private boolean forceUpdate;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
