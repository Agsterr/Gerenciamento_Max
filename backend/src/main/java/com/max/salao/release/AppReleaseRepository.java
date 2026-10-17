package com.max.salao.release;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface AppReleaseRepository extends JpaRepository<AppRelease, Long> {

    Optional<AppRelease> findFirstByAppOrderByVersionCodeDesc(String app);

    List<AppRelease> findByAppOrderByVersionCodeDesc(String app);

    List<AppRelease> findAllByOrderByAppAscVersionCodeDesc();

    boolean existsByAppAndVersionCode(String app, int versionCode);
}
