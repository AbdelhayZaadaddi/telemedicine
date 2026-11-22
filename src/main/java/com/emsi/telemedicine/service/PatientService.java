package com.emsi.telemedicine.service;

import com.emsi.telemedicine.dto.PatientDTO;
import com.emsi.telemedicine.entity.Patient;
import com.emsi.telemedicine.exception.ConflictException;
import com.emsi.telemedicine.exception.ResourceNotFoundException;
import com.emsi.telemedicine.repository.PatientRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import java.util.List;

@ApplicationScoped
@Transactional
public class PatientService {

    @Inject
    private PatientRepository repository;

    public List<PatientDTO> findAll() {
        return repository.findAll().stream().map(PatientDTO::fromEntity).toList();
    }

    public PatientDTO findById(Long id) {
        return PatientDTO.fromEntity(getOrThrow(id));
    }

    public PatientDTO create(PatientDTO dto) {
        checkEmailAvailable(dto.email(), null);
        Patient patient = new Patient();
        dto.applyTo(patient);
        return PatientDTO.fromEntity(repository.save(patient));
    }

    public PatientDTO update(Long id, PatientDTO dto) {
        Patient patient = getOrThrow(id);
        checkEmailAvailable(dto.email(), id);
        dto.applyTo(patient);
        return PatientDTO.fromEntity(repository.save(patient));
    }

    public void delete(Long id) {
        repository.delete(getOrThrow(id));
    }

    private Patient getOrThrow(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Patient introuvable : id=" + id));
    }

    private void checkEmailAvailable(String email, Long currentId) {
        repository.findByEmail(email)
                .filter(existing -> !existing.getId().equals(currentId))
                .ifPresent(existing -> {
                    throw new ConflictException("Email déjà utilisé : " + email);
                });
    }
}
