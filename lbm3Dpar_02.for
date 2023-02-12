C================================================
C     LBM2D - from python code by Jonas Latt
C================================================
      module allocated
        INTEGER,  ALLOCATABLE :: obs(:,:,:)
        REAL,     ALLOCATABLE :: vin(:,:,:)
        REAL,     ALLOCATABLE :: vel(:,:,:,:)
        REAL,     ALLOCATABLE :: fin(:,:,:,:)
        REAL,     ALLOCATABLE :: fout(:,:,:,:)
        REAL,     ALLOCATABLE :: feq(:,:,:,:)
        REAL,     ALLOCATABLE :: rho(:,:,:)
      end module allocated
C===========================================

      program main
      use allocated
      implicit none




CCC   integer, parameter :: ndim=2, nvec=9
      integer, parameter :: ndim=3, nvec=15, nrow=5

      integer i,j,k,n,c,ni,nj,nk
      integer im,jm,km ! obstacle
      integer writeits,writevtk,maxits
      integer vec(nvec,ndim),col1(nrow),col2(nrow),col3(nrow)
      integer its,nexti,nextj,nextk,iseq

      real lref,re,uLB,nuLB,omega,sum2,sum3,cu,usqr
      real cx,cy,cz,cr,xx,yy,zz,vmag_sum,vmag
      real wt(nvec)

      CHARACTER(30) outfile
      CHARACTER(6)  string

      write(6,*) "------------------------"
      write(6,*) "to change openmp procs  "
      write(6,*) "------------------------"
      write(6,*) "set  OMP_NUM_THREADS=4  "
      write(6,*) "echo %OMP_NUM_THREADS%  "
      write(6,*) "------------------------"
      write(6,*) "export OMP_NUM_THREADS=4"
      write(6,*) "echo $OMP_NUM_THREADS   "
      write(6,*) "------------------------"

      
C=====constants
      write(6,*) "constants"
      maxits   = 100 ! max iterations
      writevtk = 100
      writeits = 1
      iseq = 1
C-----
      Re = 20.0          ! reynolds number
      ni = 600           ! lattice nodes
      nj = 100           ! lattice nodes
      nk = 200           ! lattice nodes
      cx = real(ni)/4.0  ! sphere x-coord
      cy = real(nj)/2.0  ! sphere y-coord
      cz = real(nk)/2.0  ! sphere z-coord
      cr = real(nj)/8.0  ! sphere radius, in terms of nj dimension
      Lref  = 10         ! length scale (prev Lref = cylinder radius)
      uLB   = 0.04       ! velocity in lattice units
      nuLB  = uLB*Lref/Re            ! viscosity in lattice units
      omega = 1.0 / (3.0*nuLB + 0.5) ! relaxation parameter

      WRITE(6,*) 'ni = ',ni
      WRITE(6,*) 'nj = ',nj
      WRITE(6,*) 'nk = ',nk
      WRITE(6,*) 'mesh = ',ni*nj*nk

C=====allocate
      ALLOCATE( obs(ni,nj,nk) ) ! 3D
      ALLOCATE( vin(nj,nk,ndim) )    ! 2D array
      ALLOCATE( vel(ni,nj,nk,ndim) ) ! 3D
      ALLOCATE( fin(ni,nj,nk,nvec) ) ! 3D
      ALLOCATE(fout(ni,nj,nk,nvec) ) ! 3D
      ALLOCATE( feq(ni,nj,nk,nvec) ) ! 3D
      ALLOCATE( rho(ni,nj,nk) )      ! 3D

C=====initialise vectors
      vec(1, :) = (/ 1, 0, 0 /)
      vec(2, :) = (/ 0, 1, 0 /)
      vec(3, :) = (/ 0, 0, 1 /)
      vec(4, :) = (/ 1, 1, 1 /) 
      vec(5, :) = (/ 1, 1,-1 /)
      vec(6, :) = (/ 1,-1, 1 /) 
      vec(7, :) = (/ 1,-1,-1 /) 
      vec(8, :) = (/ 0, 0, 0 /)  
      vec(9, :) = (/-1, 1, 1 /)
      vec(10,:) = (/-1, 1,-1 /)
      vec(11,:) = (/-1,-1, 1 /)
      vec(12,:) = (/-1,-1,-1 /)
      vec(13,:) = (/ 0, 0,-1 /)
      vec(14,:) = (/ 0,-1, 0 /) 
      vec(15,:) = (/-1, 0, 0 /)

C=====initialise weights

      wt(1)  = 1./9.
      wt(2)  = 1./9.
      wt(3)  = 1./9.
      wt(4)  = 1./72.
      wt(5)  = 1./72.
      wt(6)  = 1./72.
      wt(7)  = 1./72.
      wt(8)  = 2./9.
      wt(9)  = 1./72.
      wt(10) = 1./72.
      wt(11) = 1./72.
      wt(12) = 1./72.
      wt(13) = 1./9.
      wt(14) = 1./9.
      wt(15) = 1./9.

      col1 = (/ 1,  4,  5,  6,   7 /)
      col2 = (/ 2,  3,  8,  13, 14 /)
      col3 = (/ 9,  10, 11, 12, 15 /)

      obs = 1    ! integer 3d array
      vin = 0.0  ! real array
      fin = 0.0  ! real array
      fout= 0.0  ! real array
      feq = 0.0  ! real array
      rho = 0.0  ! real array
      vel = 0.0  ! real array

C=====obstacle

C-----original sphere geometry
      if (.false.) then       
      do k = 1,nk
      do j = 1,nj
      do i = 1,ni
        xx = real(i-1) + 0.5
        yy = real(j-1) + 0.5
        zz = real(k-1) + 0.5
        if (((xx-cx)**2+(yy-cy)**2+(zz-cz)**2) .LT. (cr**2)) then
          obs(i,j,k) = 0
        endif
      enddo
      enddo
      enddo
      endif

C=====change obs to match lcd array from ufocfd
      IF (.true.) THEN
        WRITE(6,*) 'read obstacle'
        OPEN(UNIT=20, FILE="obstacle.dat")
        READ(20,*) im,jm,km
        if (im.ne.ni) stop
        if (jm.ne.nj) stop
        if (km.ne.nk) stop
        READ(20,*)(((obs(i,j,k),i=1,im),j=1,jm),k=1,km)
        CLOSE(20)
      ENDIF

C=====inlet profile (vin)
      write(6,*)"inlet profile"
      do k = 1,nk
      do j = 1,nj
        vin(j,k,1) = uLB
        vin(j,k,2) = 0.0
        vin(j,k,3) = 0.0
      enddo
      enddo

C=====initial velocity field
      write(6,*)"initial velocity"
      do k = 1,nk
      do j = 1,nj
      do i = 1,ni
        if (obs(i,j,k).LT.0) then
          vel(i,j,k,1) = 0.0
          vel(i,j,k,2) = 0.0
          vel(i,j,k,3) = 0.0
        else
          vel(i,j,k,1) = vin(j,k,1)
          vel(i,j,k,2) = vin(j,k,2)
          vel(i,j,k,3) = vin(j,k,3)
        endif
      enddo
      enddo
      enddo

C=====equilibrium distribution function
C-----fin = equilibrium(1,u)
      do k = 1,nk
      do j = 1,nj
      do i = 1,ni

        usqr = vel(i,j,k,1)**2 + vel(i,j,k,2)**2 + vel(i,j,k,3)**2
        do n = 1,nvec
          cu = vec(n,1)*vel(i,j,k,1)
     &       + vec(n,2)*vel(i,j,k,2)
     &       + vec(n,3)*vel(i,j,k,3)
          fin(i,j,k,n) = 1.0*wt(n)*(1.0 + 3.0*cu + 4.5*cu**2 - 1.5*usqr)
        enddo

      enddo
      enddo
      enddo

      write(6,*)"start iterations"

C-----steps which are slowest 1357


C=====iteration loop
      do its = 1,maxits

C-------right wall outflow condition
        do k = 1,nk
        do j = 1,nj
          do c = 1,nrow
            fin(ni,j,k,col3(c)) = fin(ni-1,j,k,col3(c))
          enddo
        enddo
        enddo



C       write(6,*)"step1"
C=======compute macroscopic variables rho and u
        rho = 0.0
        vel = 0.0
!$OMP PARALLEL DO
!$OMP&PRIVATE(i,j,k,n)
        do k = 1,nk
        do j = 1,nj
        do i = 1,ni

          do n = 1,nvec
            rho(i,j,k) = rho(i,j,k) + fin(i,j,k,n)
            vel(i,j,k,1) = vel(i,j,k,1) + vec(n,1) * fin(i,j,k,n)
            vel(i,j,k,2) = vel(i,j,k,2) + vec(n,2) * fin(i,j,k,n)
            vel(i,j,k,3) = vel(i,j,k,3) + vec(n,3) * fin(i,j,k,n)
          enddo

          vel(i,j,k,1) = vel(i,j,k,1) / rho(i,j,k)
          vel(i,j,k,2) = vel(i,j,k,2) / rho(i,j,k)
          vel(i,j,k,3) = vel(i,j,k,3) / rho(i,j,k)

        enddo
        enddo
        enddo
!$OMP END PARALLEL DO
C====================



C=======left wall inflow condition
C       write(6,*)"step2"
        do k = 1,nk
        do j = 1,nj
          vel(1,j,k,1) = vin(j,k,1)
          vel(1,j,k,2) = vin(j,k,2)
          vel(1,j,k,3) = vin(j,k,3)
          sum2 = 0.0
          sum3 = 0.0
          do c = 1,nrow
            sum2 = sum2 + fin(1,j,k,col2(c))
            sum3 = sum3 + fin(1,j,k,col3(c))
            rho(1,j,k) = (sum2 + 2.0*sum3) / (1.0-vel(1,j,k,1))
          enddo
        enddo
        enddo



C       write(6,*)"step3"
C=======compute equilibrium (rho, vel)
!$OMP PARALLEL DO
!$OMP&PRIVATE(i,j,k,n,usqr,cu)
        do k = 1,nk
        do j = 1,nj
        do i = 1,ni

          usqr = vel(i,j,k,1)**2 + vel(i,j,k,2)**2 + vel(i,j,k,3)**2
          do n = 1,nvec
            cu = vec(n,1)*vel(i,j,k,1)
     &         + vec(n,2)*vel(i,j,k,2)
     &         + vec(n,3)*vel(i,j,k,3)
            feq(i,j,k,n) = rho(i,j,k)*wt(n)*(1.0 + 3.0*cu
     &                               + 4.5*cu**2 - 1.5*usqr)
          enddo

        enddo
        enddo
        enddo
!$OMP END PARALLEL DO
C====================



C-------calculate populations (at inlet)       
C       write(6,*)"step4"
        do j = 1,nj
        do k = 1,nk
          do c = 1,nrow
            fin(1,j,k,col1(c)) = feq(1,j,k,col1(c))
     &                         + fin(1,j,k,col3(6-c))
     &                         - feq(1,j,k,col3(6-c))
          enddo
        enddo
        enddo



C       write(6,*)"step5"
C-------collision step
!$OMP PARALLEL DO
!$OMP&PRIVATE(i,j,k,n)
        do k = 1,nk
        do j = 1,nj
        do i = 1,ni
          do n = 1,nvec
            fout(i,j,k,n) = fin(i,j,k,n)
     &                    - omega*(fin(i,j,k,n) - feq(i,j,k,n))
          enddo
        enddo
        enddo
        enddo
!$OMP END PARALLEL DO
C====================



C       write(6,*)"step6"
C=======obstacle
!$OMP PARALLEL DO
!$OMP&PRIVATE(i,j,k,n)
        do k = 1,nk
        do j = 1,nj
        do i = 1,ni

C---------bounce-back condition
          if (obs(i,j,k).LE.0) then
            do n = 1,nvec
              fout(i,j,k,n) = fin(i,j,k,16-n)
            enddo
          endif

        enddo
        enddo
        enddo
!$OMP END PARALLEL DO
C====================



C       write(6,*)"step7"
C-------streaming step
!$OMP PARALLEL DO
!$OMP&PRIVATE(i,j,k,n,nexti,nextj,nextk)
        do k = 1,nk
        do j = 1,nj
        do i = 1,ni

          do n = 1,nvec

            nexti = i + vec(n,1)
            if (nexti.lt.1)  nexti = ni
            if (nexti.gt.ni) nexti = 1

            nextj = j + vec(n,2)
            if (nextj.lt.1)  nextj = nj
            if (nextj.gt.nj) nextj = 1

            nextk = k + vec(n,3)
            if (nextk.lt.1)  nextk = nk
            if (nextk.gt.nk) nextk = 1

            fin(nexti,nextj,nextk,n) = fout(i,j,k,n)

          enddo

        enddo
        enddo
        enddo
!$OMP END PARALLEL DO
C====================



C       write(6,*)"step8"
C-------residuals
        vmag_sum = 0.0
!$OMP PARALLEL DO
!$OMP&PRIVATE(i,j,k,vmag)
!$OMP&REDUCTION(+:vmag_sum)
        do k = 1,nk
        do j = 1,nj
        do i = 1,ni
          vmag = sqrt(vel(i,j,k,1)**2
     &              + vel(i,j,k,2)**2
     &              + vel(i,j,k,3)**2)
          vmag_sum = vmag_sum + vmag
        enddo
        enddo
        enddo
!$OMP END PARALLEL DO
C====================

C-------write iterations
        if (mod(its,writeits).eq.0)
          write(6,*)its,vmag_sum
        endif

C-------start vtk file
        if (mod(its,writevtk).eq.0) then

C---------make outfile
          if (iseq.eq.0) then
            outfile = './vtkfiles/lbm2d.vtk'
          elseif (iseq.eq.1) then
            write(unit=string, fmt='(I6.6)') its
            outfile = './vtkfiles/lbm2d_'//string//'.vtk'
          endif
          write(6,*)"outfile=",outfile

C---------start ascii VTK file
          OPEN(unit=20,file=outfile)
          write(20,10)'# vtk DataFile Version 3.0'
          write(20,10)'vtk output'
          write(20,10)'ASCII'
          write(20,10)'DATASET RECTILINEAR_GRID'
          write(20,20)'DIMENSIONS ',ni+1,nj+1,nk+1
          write(20,30)'X_COORDINATES ',ni+1,' float'
          write(20,*)   (real(i-1),i=1,ni+1)
          write(20,30)'Y_COORDINATES ',nj+1,' float'
          write(20,*)   (real(j-1),j=1,nj+1)
          WRITE(20,30)'Z_COORDINATES ',nk+1,' float'
          write(20,*)   (real(k-1),k=1,nk+1)
          write(20,40)'CELL_DATA ',ni*nj*nk
C---------obstacle
          write(20,10)'SCALARS obstacle int'
          write(20,10)'LOOKUP_TABLE default'
          write(20,*)(((obs(i,j,k),i=1,ni),j=1,nj),k=1,nk)
C---------density
          write(20,10)'SCALARS density float'
          write(20,10)'LOOKUP_TABLE default'
          write(20,*)(((rho(i,j,k),i=1,ni),j=1,nj),k=1,nk)
C---------velocity
          write(20,10)'VECTORS velocity float'
          write(20,*)(((vel(i,j,k,1),vel(i,j,k,2),vel(i,j,k,3),
     &                                 i=1,ni),j=1,nj),k=1,nk)
          close(20)
C---------finish ascii VTK file




C---------start binary VTK file


C---------finish binary VTK file




        endif
C-------finish vtk file

      enddo ! maxits
C=====iteration loop

      write(6,*) "finished"

   10 format(A)
   20 format(A,3I4)
   30 format(A,I3,A)
   40 format(A,I9)

      end ! main







